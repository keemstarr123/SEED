import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:image/image.dart' as img;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiExtractionService {
  final String _model =
      'gemini-3.1-flash-lite-preview'; // Latest stable model for the Google AI SDK

  final _scopes = ['https://www.googleapis.com/auth/cloud-platform'];

  Future<auth.AuthClient> _getAuthClient() async {
    final jsonCredentials = await rootBundle.loadString(
      'assets/GCPServiceAccountKey.json',
    );
    final credentials = auth.ServiceAccountCredentials.fromJson(
      jsonCredentials,
    );
    return auth.clientViaServiceAccount(credentials, _scopes);
  }

  Future<Map<String, dynamic>> extractAndGroupMenu(
    List<Uint8List> imagesBytes,
  ) async {
    // 1. Vision API Call (Requires Service Account Auth)
    final authClient = await _getAuthClient();
    final visionUrl = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate',
    );

    // Consolidated context across all uploaded images
    Map<String, List<Map<String, double>>> masterVisionRegistry = {};
    List<Map<String, dynamic>> masterGeminiContext = [];
    List<Map<String, dynamic>> masterTextContext = [];
    List<Map<String, int>> imageDimensions = [];

    // 1. Parallel Vision API Calls
    final List<Future<Map<String, dynamic>>> visionTasks = [];
    for (int i = 0; i < imagesBytes.length; i++) {
      visionTasks.add(
        _processVisionForImage(authClient, visionUrl, imagesBytes[i], i),
      );
    }

    final results = await Future.wait(visionTasks);

    debugPrint('------- Vision API Results Summary -------');
    for (var res in results) {
      final int idx = res['imageIdx'];
      final int icons = (res['geminiContext'] as List).length;
      final int texts = (res['textContext'] as List).length;
      debugPrint('Image $idx: $icons objects found, $texts text blocks found.');

      masterVisionRegistry.addAll(
        res['visionRegistry'] as Map<String, List<Map<String, double>>>,
      );
      masterGeminiContext.addAll(
        res['geminiContext'] as List<Map<String, dynamic>>,
      );
      masterTextContext.addAll(
        res['textContext'] as List<Map<String, dynamic>>,
      );
      imageDimensions.add(res['dimensions'] as Map<String, int>);
    }

    // 2. Gemini Reasoning via Google AI SDK
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("GEMINI_API_KEY not found in .env file");
    }

    final generationConfig = GenerationConfig(
      maxOutputTokens: 65535,
      temperature: 0.1,
      topP: 0.95,
      responseMimeType: 'application/json',
    );

    final model = GenerativeModel(
      model: _model,
      apiKey: apiKey,
      generationConfig: generationConfig,
    );

    final systemInstruction = '''
Role: You are an expert menu parser for a Malaysian micro-business POS system.
Task: Extract every product listed in the menu from the provided text and images.
Priority: TEXT IS ALWAYS THE PRIMARY SOURCE. Images are optional extras — do not skip a product just because it has no photo.
Goal: Return ALL unique products found in valid JSON, regardless of whether they have an associated image.
''';

    final prompt = '''
Context:
Canvas Context (Images 0 to ${imagesBytes.length - 1}): ${jsonEncode(imageDimensions)}
Detected Objects (from Vision API, may be empty): ${jsonEncode(masterGeminiContext)}
Detected Text (primary source): ${jsonEncode(masterTextContext)}

Instructions:
1. TEXT-FIRST EXTRACTION:
   - Scan ALL detected text blocks to find every product name and price.
   - A product is any item with a name and a price (e.g. "Nasi Lemak ... RM5.50", "Teh Tarik 3.00").
   - Do NOT skip products just because no image was detected for them.
   - If the menu is mostly or entirely text (no food photos), that is fine — extract everything from text alone.

2. Price Parsing:
   - Prices may appear as "RM5.50", "5.50", "5", or after dots/dashes.
   - If price is unclear or missing, default to 0.0.

3. Image Linking (optional — only if Vision API detected something):
   - If an image object matches the product, set 'image_id' and 'image_crop_box'.
   - If NO matching image exists, set 'image_id' to null and 'image_crop_box' to null. This is perfectly valid.
   - Set 'has_image' to true only if a real crop box is available.

4. Keyword Generation (for voice ordering):
   - Short, easy to say (e.g. "Nasi Lemak" not "Nasi Lemak Special Sambal Petai Berempah").
   - Must be recognisable via speech-to-text.

5. Description:
   - One sentence. Highlight what makes this item distinct (ingredients, portion, spice level).
   - If no description is available from the menu, generate a sensible one based on the product name.

6. Category Assignment:
   - Assign one of: "Main Course", "Beverage", "Dessert", "Side Dish", "Snack", "Set Meal", or "General".
   - Be consistent for similar items.

Format (JSON Schema):
IMPORTANT: Use exact key "product_name". Do not use "name" or "item".
{
  "menu_extraction": [
    {
      "product_name": "string",
      "unit_price": number,
      "keyword": "string",
      "description": "string",
      "category": "string",
      "has_image": boolean,
      "visual_justification": "string",
      "image_id": "string or null",
      "source_image_index": integer,
      "image_crop_box": { "ymin": number, "xmin": number, "ymax": number, "xmax": number } or null
    }
  ]
}
''';

    final content = [
      Content.multi([
        ...imagesBytes.map((b) => DataPart('image/jpeg', b)),
        TextPart(systemInstruction + "\n" + prompt),
      ]),
    ];

    final response = await model.generateContent(content);
    String? generatedText = response.text;
    if (generatedText == null) throw Exception("Gemini returned null response");

    print("------- GEMINI RAW RESPONSE (MULTI) -------");
    print(generatedText);

    // Deep JSON Extraction Logic
    Map<String, dynamic> geminiData = {};
    try {
      String cleanedJson = generatedText.trim();

      // Remove Markdown code blocks if present
      if (cleanedJson.contains("```")) {
        final regex = RegExp(r"```(?:json)?\s*([\s\S]*?)\s*```");
        final match = regex.firstMatch(cleanedJson);
        if (match != null) {
          cleanedJson = match.group(1)!;
        } else {
          // Fallback: search for first [ or {
          int startBracket = cleanedJson.indexOf('{');
          int startArray = cleanedJson.indexOf('[');
          int start =
              (startBracket != -1 &&
                  (startArray == -1 || startBracket < startArray))
              ? startBracket
              : startArray;
          int end = cleanedJson.lastIndexOf(start == startBracket ? '}' : ']');
          if (start != -1 && end != -1) {
            cleanedJson = cleanedJson.substring(start, end + 1);
          }
        }
      }

      final decoded = jsonDecode(cleanedJson);
      if (decoded is Map) {
        geminiData = Map<String, dynamic>.from(decoded);
      } else if (decoded is List) {
        geminiData = {'menu_extraction': decoded};
      }
    } catch (e) {
      print("JSON Parse Error: $e");
      throw Exception("Failed to parse AI response. Please try again.");
    }

    authClient.close();

    // 6. Post-Processing Integration
    List<Map<String, dynamic>> finalProducts = [];

    // Find the actual list of products more flexibly
    List<dynamic> products = [];
    if (geminiData.containsKey('menu_extraction')) {
      products = geminiData['menu_extraction'] as List;
    } else if (geminiData.containsKey('products')) {
      products = geminiData['products'] as List;
    } else if (geminiData.containsKey('items')) {
      products = geminiData['items'] as List;
    } else {
      // Look for any list in the map
      for (var value in geminiData.values) {
        if (value is List) {
          products = value;
          break;
        }
      }
    }

    for (var pMap in products) {
      if (pMap is! Map) continue;
      final p = pMap.map(
        (k, v) => MapEntry(k.toString().toLowerCase().trim(), v),
      );

      // Robust field extraction
      String name =
          (p['product_name'] ??
                  p['name'] ??
                  p['item'] ??
                  p['product'] ??
                  p['label'] ??
                  'Unknown Item')
              .toString();
      String description = (p['description'] ?? p['desc'] ?? p['details'] ?? '')
          .toString();
      double price = (p['unit_price'] ?? p['price'] ?? p['rate'] ?? 0.0)
          .toDouble();
      String keyword = (p['keyword'] ?? p['keywords'] ?? p['vocal'] ?? name)
          .toString();
      String category = (p['category'] ?? p['type'] ?? p['group'] ?? 'General')
          .toString();
      String justification =
          (p['visual_justification'] ??
                  p['justification'] ??
                  p['location_justification'] ??
                  '')
              .toString();

      String? imageId = p['image_id']?.toString();
      int sourceIdx = (p['source_image_index'] as num? ?? 0).toInt();
      Map<String, double>? dynamicBox;

      debugPrint('Processing Product: $name (Price: $price, Cat: $category)');

      if (imageId != null && masterVisionRegistry.containsKey(imageId)) {
        final box = masterVisionRegistry[imageId]!;
        double ymin = 9999, xmin = 9999, ymax = 0, xmax = 0;
        for (var v in box) {
          if (v['y']! < ymin) ymin = v['y']!;
          if (v['x']! < xmin) xmin = v['x']!;
          if (v['y']! > ymax) ymax = v['y']!;
          if (v['x']! > xmax) xmax = v['x']!;
        }
        dynamicBox = {'ymin': ymin, 'xmin': xmin, 'ymax': ymax, 'xmax': xmax};

        final parts = imageId.split('_');
        if (parts.length >= 2) sourceIdx = int.parse(parts[1]);
      } else if (p['image_crop_box'] != null && p['image_crop_box'] is Map) {
        final cb = p['image_crop_box'] as Map;
        dynamicBox = {
          'ymin': (cb['ymin'] ?? cb['y_min'] ?? 0.0).toDouble(),
          'xmin': (cb['xmin'] ?? cb['x_min'] ?? 0.0).toDouble(),
          'ymax': (cb['ymax'] ?? cb['y_max'] ?? 0.0).toDouble(),
          'xmax': (cb['xmax'] ?? cb['x_max'] ?? 0.0).toDouble(),
        };
      }

      final hasImage = dynamicBox != null;
      finalProducts.add({
        'product_name': name,
        'description': description,
        'unit_price': price,
        'keyword': keyword,
        'category': category,
        'has_image': hasImage,
        'visual_justification': justification,
        'image_crop_box': dynamicBox, // null is fine — product still included
        'source_image_index': sourceIdx,
      });
    }

    return {'menu_extraction': finalProducts};
  }

  // Dart equivalent of crop_product
  Uint8List? cropProductImage(Uint8List sourceBytes, Map<String, dynamic> box) {
    try {
      final img.Image? originalImage = img.decodeImage(sourceBytes);
      if (originalImage == null) return null;

      int ymin = (box['ymin'] as num).toInt();
      int xmin = (box['xmin'] as num).toInt();
      int ymax = (box['ymax'] as num).toInt();
      int xmax = (box['xmax'] as num).toInt();

      if (xmax <= xmin || ymax <= ymin) return null; // Invalid box

      final cropped = img.copyCrop(
        originalImage,
        x: xmin,
        y: ymin,
        width: xmax - xmin,
        height: ymax - ymin,
      );
      return Uint8List.fromList(img.encodeJpg(cropped));
    } catch (e) {
      print('Failed to crop: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _processVisionForImage(
    auth.AuthClient authClient,
    Uri visionUrl,
    Uint8List bytes,
    int imageIdx,
  ) async {
    final visionRequest = {
      'requests': [
        {
          'image': {'content': base64Encode(bytes)},
          'features': [
            {'type': 'OBJECT_LOCALIZATION', 'maxResults': 150},
            {'type': 'DOCUMENT_TEXT_DETECTION'},
          ],
        },
      ],
    };

    final visionResp = await authClient.post(
      visionUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(visionRequest),
    );

    final visionData = jsonDecode(visionResp.body);
    final responses = (visionData['responses'] as List).first;
    final localizedObjects =
        responses['localizedObjectAnnotations'] as List? ?? [];
    final textAnnotations = responses['textAnnotations'] as List? ?? [];

    final decoded = img.decodeImage(bytes);
    int w = decoded?.width ?? 1000;
    int h = decoded?.height ?? 1000;

    Map<String, List<Map<String, double>>> visionRegistry = {};
    List<Map<String, dynamic>> geminiContext = [];
    List<Map<String, dynamic>> textContext = [];

    for (int i = 0; i < localizedObjects.length; i++) {
      final obj = localizedObjects[i];
      final String imageId = 'img_${imageIdx}_$i';
      final boundingPoly =
          obj['boundingPoly']['normalizedVertices'] as List? ?? [];
      List<Map<String, double>> rawBox = [];
      for (var v in boundingPoly) {
        rawBox.add({
          'x': ((v['x'] ?? 0.0) as num).toDouble() * w,
          'y': ((v['y'] ?? 0.0) as num).toDouble() * h,
        });
      }
      visionRegistry[imageId] = rawBox;
      geminiContext.add({
        'image_id': imageId,
        'source_image_index': imageIdx,
        'label': obj['name'],
        'approximate_location': rawBox,
      });
    }

    if (textAnnotations.isNotEmpty) {
      for (int i = 1; i < textAnnotations.length; i++) {
        final block = textAnnotations[i];
        final vertices = block['boundingPoly']['vertices'] as List? ?? [];
        textContext.add({
          'source_image_index': imageIdx,
          'text': block['description'],
          'raw_pixel_box': vertices
              .map(
                (v) => {'x': (v['x'] ?? 0) as num, 'y': (v['y'] ?? 0) as num},
              )
              .toList(),
        });
      }
    }

    return {
      'imageIdx': imageIdx,
      'visionRegistry': visionRegistry,
      'geminiContext': geminiContext,
      'textContext': textContext,
      'dimensions': {'w': w, 'h': h},
    };
  }
}
