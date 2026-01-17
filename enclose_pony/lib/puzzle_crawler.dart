// Puzzle crawler for fetching puzzles from enclose.horse
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:enclose_pony/puzzle_data.dart';

class PuzzleCrawler {
  static const String baseUrl = 'https://enclose.horse';
  
  /// Fetches all available puzzles from __DAILY_LEVELS__
  static Future<List<Map<String, dynamic>>> fetchAllPuzzles() async {
    try {
      final htmlResponse = await http.get(Uri.parse(baseUrl));
      if (htmlResponse.statusCode != 200) return [];
      
      final arrayStartPattern = RegExp(r'window\.__DAILY_LEVELS__\s*=\s*\[', multiLine: true);
      final startMatch = arrayStartPattern.firstMatch(htmlResponse.body);
      
      if (startMatch != null) {
        final startIndex = startMatch.start + startMatch.group(0)!.length - 1;
        int bracketCount = 0;
        int endIndex = startIndex;
        for (int i = startIndex; i < htmlResponse.body.length && i < startIndex + 10000; i++) {
          if (htmlResponse.body[i] == '[') bracketCount++;
          if (htmlResponse.body[i] == ']') {
            bracketCount--;
            if (bracketCount == 0) {
              endIndex = i + 1;
              break;
            }
          }
        }
        
        if (endIndex > startIndex) {
          var jsonStr = htmlResponse.body.substring(startIndex, endIndex);
          jsonStr = jsonStr.trim();
          if (jsonStr.endsWith(';')) {
            jsonStr = jsonStr.substring(0, jsonStr.length - 1).trim();
          }
          
          final levels = jsonDecode(jsonStr) as List;
          return levels.map((level) => level as Map<String, dynamic>).toList();
        }
      }
    } catch (e) {
      print('Error fetching all puzzles: $e');
    }
    return [];
  }
  
  /// Fetches a specific puzzle by ID
  static Future<PuzzleData?> fetchPuzzleById(String puzzleId, {int? dayNumber, String? puzzleDate}) async {
    try {
      final apiUrl = '$baseUrl/api/levels/$puzzleId';
      final apiResponse = await http.get(Uri.parse(apiUrl));
      
      if (apiResponse.statusCode != 200) return null;
      
      final puzzleJson = jsonDecode(apiResponse.body) as Map<String, dynamic>;
      return parsePuzzleFromAPI(puzzleJson, dayNumber: dayNumber, puzzleDate: puzzleDate);
    } catch (e) {
      print('Error fetching puzzle by ID: $e');
    }
    return null;
  }
  
  /// Fetches today's puzzle from enclose.horse
  static Future<PuzzleData?> fetchTodayPuzzle() async {
    print('=== DEBUG: fetchTodayPuzzle() called ===');
    try {
      // First, fetch the main page to get today's puzzle ID
      print('DEBUG: Fetching HTML from $baseUrl');
      final htmlResponse = await http.get(Uri.parse(baseUrl));
      print('DEBUG: HTML response status: ${htmlResponse.statusCode}');
      if (htmlResponse.statusCode != 200) {
        print('DEBUG: Failed to fetch HTML: ${htmlResponse.statusCode}');
        return null;
      }
      print('DEBUG: HTML fetched successfully, length: ${htmlResponse.body.length}');
      
      // Extract puzzle ID and metadata from __DAILY_LEVELS__
      print('DEBUG: Extracting puzzle ID and metadata from HTML...');
      final puzzleMetadata = _extractTodayPuzzleMetadata(htmlResponse.body);
      if (puzzleMetadata == null || puzzleMetadata['id'] == null) {
        print('DEBUG: Could not find today\'s puzzle ID, trying HTML parsing fallback...');
        final htmlPuzzle = parsePuzzleFromHTML(htmlResponse.body);
        if (htmlPuzzle != null) {
          print('DEBUG: Got puzzle from HTML parsing fallback');
          return htmlPuzzle;
        }
        print('DEBUG: HTML parsing also failed, returning null');
        return null;
      }
      
      final puzzleId = puzzleMetadata['id'] as String;
      final dayNumber = puzzleMetadata['dayNumber'] as int?;
      final puzzleDate = puzzleMetadata['date'] as String?;
      
      print('DEBUG: Found today\'s puzzle ID: $puzzleId, dayNumber: $dayNumber, date: $puzzleDate');
      
      // Fetch the actual puzzle data from the API
      final apiUrl = '$baseUrl/api/levels/$puzzleId';
      print('DEBUG: Fetching puzzle from API: $apiUrl');
      final apiResponse = await http.get(Uri.parse(apiUrl));
      print('DEBUG: API response status: ${apiResponse.statusCode}');
      
      if (apiResponse.statusCode != 200) {
        print('DEBUG: Failed to fetch puzzle data: ${apiResponse.statusCode}');
        print('DEBUG: Response body: ${apiResponse.body}');
        return null; // Return null so we can use default puzzle
      }
      
      print('DEBUG: API response received, length: ${apiResponse.body.length}');
      print('DEBUG: API response body (first 500 chars): ${apiResponse.body.substring(0, apiResponse.body.length > 500 ? 500 : apiResponse.body.length)}');
      
      // Parse the JSON response
      try {
        print('DEBUG: Parsing JSON response...');
        final puzzleJson = jsonDecode(apiResponse.body) as Map<String, dynamic>;
        print('DEBUG: JSON parsed successfully, keys: ${puzzleJson.keys.join(", ")}');
        print('DEBUG: Calling parsePuzzleFromAPI...');
        final puzzle = parsePuzzleFromAPI(puzzleJson, dayNumber: dayNumber, puzzleDate: puzzleDate);
        if (puzzle != null) {
          print('DEBUG: ✅ Successfully loaded puzzle:');
          print('DEBUG:    - levelId: ${puzzle.levelId}');
          print('DEBUG:    - gridSize: ${puzzle.gridSize}x${puzzle.gridSize}');
          print('DEBUG:    - maxWalls: ${puzzle.maxWalls}');
          print('DEBUG:    - horseRow: ${puzzle.horseRow}, horseCol: ${puzzle.horseCol}');
          print('DEBUG:    - cells count: ${puzzle.cells.length}');
          print('DEBUG:    - portals count: ${puzzle.portals.length}');
        } else {
          print('DEBUG: ❌ parsePuzzleFromAPI returned null');
        }
        return puzzle;
      } catch (e, stackTrace) {
        print('DEBUG: ❌ Error parsing API response: $e');
        print('DEBUG: Stack trace: $stackTrace');
        print('DEBUG: Response body: ${apiResponse.body}');
        return null;
      }
      
    } catch (e, stackTrace) {
      print('DEBUG: ❌ Error fetching puzzle: $e');
      print('DEBUG: Stack trace: $stackTrace');
    }
    print('DEBUG: Returning null from fetchTodayPuzzle');
    return null;
  }
  
  /// Extracts today's puzzle metadata (ID, dayNumber, date) from the HTML
  static Map<String, dynamic>? _extractTodayPuzzleMetadata(String htmlContent) {
    final puzzleId = _extractTodayPuzzleId(htmlContent);
    if (puzzleId == null) return null;
    
    // Now extract the full metadata from __DAILY_LEVELS__
    try {
      final arrayStartPattern = RegExp(r'window\.__DAILY_LEVELS__\s*=\s*\[', multiLine: true);
      final startMatch = arrayStartPattern.firstMatch(htmlContent);
      
      if (startMatch != null) {
        final startIndex = startMatch.start + startMatch.group(0)!.length - 1;
        int bracketCount = 0;
        int endIndex = startIndex;
        for (int i = startIndex; i < htmlContent.length && i < startIndex + 10000; i++) {
          if (htmlContent[i] == '[') bracketCount++;
          if (htmlContent[i] == ']') {
            bracketCount--;
            if (bracketCount == 0) {
              endIndex = i + 1;
              break;
            }
          }
        }
        
        if (endIndex > startIndex) {
          var jsonStr = htmlContent.substring(startIndex, endIndex);
          jsonStr = jsonStr.trim();
          if (jsonStr.endsWith(';')) {
            jsonStr = jsonStr.substring(0, jsonStr.length - 1).trim();
          }
          
          final levels = jsonDecode(jsonStr) as List;
          if (levels.isNotEmpty) {
            // Find puzzle that matches today's date
            final today = DateTime.now();
            final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
            
            print('DEBUG: Looking for puzzle with date: $todayStr');
            print('DEBUG: Total puzzles in __DAILY_LEVELS__: ${levels.length}');
            
            Map<String, dynamic>? todayPuzzle;
            for (var level in levels) {
              final levelMap = level as Map<String, dynamic>;
              final levelDate = levelMap['date'] as String?;
              print('DEBUG: Checking puzzle ${levelMap['id']}: date=$levelDate, dayNumber=${levelMap['dayNumber']}');
              
              if (levelDate == todayStr) {
                todayPuzzle = levelMap;
                print('DEBUG: Found today\'s puzzle: ${todayPuzzle['id']}, Day ${todayPuzzle['dayNumber']}');
                break;
              }
            }
            
            // If no exact match, use the first puzzle (fallback)
            if (todayPuzzle == null) {
              print('DEBUG: No puzzle found for today ($todayStr), using first puzzle as fallback');
              todayPuzzle = levels[0] as Map<String, dynamic>;
            }
            
            return {
              'id': todayPuzzle['id'],
              'dayNumber': todayPuzzle['dayNumber'],
              'date': todayPuzzle['date'],
              'name': todayPuzzle['name'],
            };
          }
        }
      }
    } catch (e) {
      print('Error extracting puzzle metadata: $e');
    }
    
    // Fallback: return just the ID
    return {'id': puzzleId};
  }
  
  /// Extracts today's puzzle ID from the HTML
  static String? _extractTodayPuzzleId(String htmlContent) {
    try {
      // Look for window.__DAILY_LEVELS__ = [{...}, {...}, ...]
      // The first element is today's puzzle
      // Find the start of the array
      final arrayStartPattern = RegExp(r'window\.__DAILY_LEVELS__\s*=\s*\[', multiLine: true);
      final startMatch = arrayStartPattern.firstMatch(htmlContent);
      
      if (startMatch != null) {
        // Position of the opening bracket '['
        final startIndex = startMatch.start + startMatch.group(0)!.length - 1;
        
        // Find matching closing bracket by counting brackets
        int bracketCount = 0;
        int endIndex = startIndex;
        for (int i = startIndex; i < htmlContent.length && i < startIndex + 10000; i++) {
          if (htmlContent[i] == '[') {
            bracketCount++;
          } else if (htmlContent[i] == ']') {
            bracketCount--;
            if (bracketCount == 0) {
              endIndex = i + 1;
              break;
            }
          }
        }
        
        if (endIndex > startIndex) {
          var jsonStr = htmlContent.substring(startIndex, endIndex);
          jsonStr = jsonStr.trim();
          
          // Remove trailing semicolon if present
          if (jsonStr.endsWith(';')) {
            jsonStr = jsonStr.substring(0, jsonStr.length - 1).trim();
          }
          
          try {
            final levels = jsonDecode(jsonStr) as List;
            if (levels.isNotEmpty) {
              final todayPuzzle = levels[0] as Map<String, dynamic>;
              final id = todayPuzzle['id'] as String?;
              print('Extracted puzzle ID: $id from ${levels.length} levels');
              return id;
            }
          } catch (e) {
            print('Error parsing DAILY_LEVELS JSON: $e');
            print('JSON string (first 500 chars): ${jsonStr.substring(0, jsonStr.length > 500 ? 500 : jsonStr.length)}');
          }
        } else {
          print('Could not find matching closing bracket for __DAILY_LEVELS__');
        }
      } else {
        print('Could not find __DAILY_LEVELS__ pattern in HTML');
      }
    } catch (e) {
      print('Error extracting puzzle ID: $e');
    }
    return null;
  }
  
  /// Parses puzzle data from the API JSON response
  static PuzzleData? parsePuzzleFromAPI(Map<String, dynamic> json, {int? dayNumber, String? puzzleDate}) {
    try {
      final id = json['id'] as String?;
      final map = json['map'] as String?;
      final budget = json['budget'] as int?;
      final name = json['name'] as String?;
      
      if (map == null) {
        print('No map data in API response');
        return null;
      }
      
      // Parse the map string
      final lines = map.split('\n').where((line) => line.trim().isNotEmpty).toList();
      if (lines.isEmpty) {
        print('Empty map data');
        return null;
      }
      
      // Calculate width from the longest line (some lines might be shorter)
      final width = lines.map((l) => l.length).reduce((a, b) => a > b ? a : b);
      final height = lines.length;
      
      print('Parsing puzzle: ${width}x${height}, budget: $budget, name: $name');
      final cells = <int, CellType>{};
      final portals = <int, Map<int, int>>{}; // Maps portal ID to list of cell indices
      int? horseRow, horseCol;
      
      // Parse each cell
      for (int row = 0; row < height; row++) {
        final line = lines[row];
        for (int col = 0; col < line.length && col < width; col++) {
          final char = line[col];
          final index = row * width + col;
          
          switch (char) {
            case '.':
              cells[index] = CellType.grass;
              break;
            case '~':
              cells[index] = CellType.water;
              break;
            case 'H':
              cells[index] = CellType.horse;
              horseRow = row;
              horseCol = col;
              break;
            case 'C':
            case 'c':
              cells[index] = CellType.cherry;
              break;
            case '0':
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
              // This is a portal - number represents portal ID
              cells[index] = CellType.portal;
              final portalId = int.parse(char);
              if (!portals.containsKey(portalId)) {
                portals[portalId] = {};
              }
              portals[portalId]![index] = index; // Store index
              break;
            default:
              // Unknown character, default to grass
              cells[index] = CellType.grass;
          }
        }
      }
      
      // Connect portals (portals with the same ID are connected)
      // Portals with the same numeric ID (0, 1, 2, etc.) are connected
      final portalConnections = <int, int>{};
      
      // Group portals by their ID (the character in the map)
      for (final entry in portals.entries) {
        final portalId = entry.key; // This is the portal ID (0, 1, 2, etc.)
        final portalIndices = entry.value.keys.toList();
        
        if (portalIndices.length >= 2) {
          // Connect all portals with the same ID in a chain or pairs
          // For most puzzles, portals appear in pairs, so connect first with second, etc.
          for (int i = 0; i < portalIndices.length - 1; i += 2) {
            final portal1 = portalIndices[i];
            final portal2 = portalIndices[i + 1];
            portalConnections[portal1] = portal2;
            portalConnections[portal2] = portal1;
            
            // If there are more than 2 portals with same ID, connect remaining
            // For now, just connect in pairs - this handles most cases
          }
        }
      }
      
      print('Found ${cells.values.where((c) => c == CellType.horse).length} horse(s)');
      print('Found ${cells.values.where((c) => c == CellType.water).length} water tiles');
      print('Found ${cells.values.where((c) => c == CellType.cherry).length} cherries');
      print('Found ${cells.values.where((c) => c == CellType.portal).length} portals');
      print('Portal connections: ${portalConnections.length}');
      
      // Parse date from puzzleDate string or createdAt timestamp
      DateTime? parsedDate;
      if (puzzleDate != null) {
        try {
          parsedDate = DateTime.parse(puzzleDate);
        } catch (e) {
          print('Error parsing puzzle date: $e');
        }
      }
      if (parsedDate == null && json['createdAt'] != null) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as int) * 1000);
      }
      
      // Create day string from dayNumber parameter
      String? dayString;
      if (dayNumber != null) {
        dayString = 'Day $dayNumber';
      }
      
      final puzzle = PuzzleData(
        gridSize: width,
        cells: cells,
        portals: portalConnections,
        maxWalls: budget ?? 11,
        horseRow: horseRow ?? height ~/ 2,
        horseCol: horseCol ?? width ~/ 2,
        day: dayString,
        levelId: id,
        date: parsedDate,
        puzzleUrl: '$baseUrl/api/levels/$id',
        puzzleName: json['name'] as String?,
        creatorName: json['creatorName'] as String?,
      );
      
      print('DEBUG: PuzzleData created:');
      print('DEBUG:    - gridSize: ${puzzle.gridSize}');
      print('DEBUG:    - cells map size: ${puzzle.cells.length}');
      print('DEBUG:    - portals map size: ${puzzle.portals.length}');
      print('DEBUG:    - maxWalls: ${puzzle.maxWalls}');
      print('DEBUG:    - horse position: (${puzzle.horseRow}, ${puzzle.horseCol})');
      
      return puzzle;
    } catch (e) {
      print('Error parsing puzzle from API: $e');
    }
    return null;
  }
  
  /// Parses puzzle data from HTML
  static PuzzleData? parsePuzzleFromHTML(String htmlContent) {
    try {
      // Debug: Print first 2000 chars of HTML to see structure
      print('=== HTML Content Preview (first 2000 chars) ===');
      print(htmlContent.substring(0, htmlContent.length > 2000 ? 2000 : htmlContent.length));
      print('=== End Preview ===');
      
      final document = html_parser.parse(htmlContent);
      
      // Extract metadata first
      String? day;
      String? levelId;
      DateTime? date;
      
      // Try to find day/level information in the page
      // Look for text patterns like "Day 1", "Level 42", etc.
      final bodyText = document.body?.text ?? '';
      
      // Pattern: "Day X" or "Day X:" or similar
      final dayMatch = RegExp(r'Day\s+(\d+)', caseSensitive: false).firstMatch(bodyText);
      if (dayMatch != null) {
        day = 'Day ${dayMatch.group(1)}';
      }
      
      // Pattern: "Level X" or "Level ID: X"
      final levelMatch = RegExp(r'Level\s*(?:ID:?\s*)?(\d+|[A-Z0-9]+)', caseSensitive: false).firstMatch(bodyText);
      if (levelMatch != null) {
        levelId = levelMatch.group(1);
      }
      
      // Try to find date in meta tags or page content
      final dateMeta = document.querySelector('meta[property="article:published_time"]') ??
                      document.querySelector('meta[name="date"]');
      if (dateMeta != null) {
        try {
          date = DateTime.parse(dateMeta.attributes['content'] ?? '');
        } catch (e) {
          // Ignore parse errors
        }
      }
      
      // If no date found, use today's date
      if (date == null) {
        date = DateTime.now();
      }
      
      // Try to find puzzle data in script tags (common pattern for web games)
      final scriptTags = document.querySelectorAll('script');
      
      // Look for JSON data or puzzle configuration
      // Try ALL scripts, not just ones containing 'grid' or 'puzzle'
      for (var script in scriptTags) {
        final content = script.text;
        
        // Try to extract puzzle data from any script
        final puzzleData = _extractPuzzleFromScript(content, day: day, levelId: levelId, date: date);
        if (puzzleData != null) return puzzleData;
      }
      
      // Pattern 2: Look for canvas or grid element and parse from HTML attributes
      final gridElement = document.querySelector('[id*="grid"]') ?? 
                         document.querySelector('[class*="grid"]') ??
                         document.querySelector('canvas');
      
      if (gridElement != null) {
        final puzzle = _parsePuzzleFromGridElement(gridElement, document, day: day, levelId: levelId, date: date);
        if (puzzle != null) return puzzle;
      }
      
      // Pattern 3: Look for data attributes
      final dataElement = document.querySelector('[data-grid]') ?? 
                         document.querySelector('[data-puzzle]');
      
      if (dataElement != null) {
        final puzzle = _parsePuzzleFromDataAttributes(dataElement, day: day, levelId: levelId, date: date);
        if (puzzle != null) return puzzle;
      }
      
      // If no puzzle data found but we have metadata, return default with metadata
      return createDefaultPuzzle(day: day, levelId: levelId, date: date);
      
    } catch (e) {
      print('Error parsing puzzle HTML: $e');
    }
    
    return null;
  }
  
  /// Extracts puzzle data from JavaScript/JSON in script tags
  static PuzzleData? _extractPuzzleFromScript(String scriptContent, {String? day, String? levelId, DateTime? date}) {
    try {
      // Extract maxWalls first
      int? extractedMaxWalls;
      final wallsMatch = RegExp(r'(?:maxWalls|maxW|walls)\s*[:=]\s*(\d+)', caseSensitive: false).firstMatch(scriptContent);
      if (wallsMatch != null) {
        extractedMaxWalls = int.tryParse(wallsMatch.group(1) ?? '');
      }
      
      // Pattern 1: Look for const/let/var grid = [[...], [...], ...]
      // Multi-line array pattern - more lenient
      final gridArrayPattern = RegExp(r'(?:const|let|var)\s+\w*(?:grid|board|puzzle|data)\w*\s*=\s*(\[\[[\s\S]{10,}\]\])', multiLine: true, dotAll: true);
      var match = gridArrayPattern.firstMatch(scriptContent);
      if (match != null) {
        try {
          final gridStr = match.group(1);
          if (gridStr != null) {
            final grid = jsonDecode(gridStr) as List;
            return _parsePuzzleFromGridArray(grid, day: day, levelId: levelId, date: date);
          }
        } catch (e) {
          print('Error parsing grid array pattern: $e');
        }
      }
      
      // Pattern 2: Look for nested array structure like grid: [[...]]
      final nestedArrayPattern = RegExp(r'(?:grid|board|puzzle)\s*[:=]\s*(\[\[[\s\S]*?\]\])', multiLine: true, dotAll: true);
      match = nestedArrayPattern.firstMatch(scriptContent);
      if (match != null) {
        try {
          final gridStr = match.group(1);
          if (gridStr != null) {
            final grid = jsonDecode(gridStr) as List;
            return _parsePuzzleFromGridArray(grid, day: day, levelId: levelId, date: date);
          }
        } catch (e) {
          print('Error parsing nested array: $e');
        }
      }
      
      // Pattern 3: Look for JSON object with grid property
      final jsonPattern = RegExp(r'\{[^{}]*(?:"grid"|"board"|"puzzle")[^{}]*\}', multiLine: true, dotAll: true);
      match = jsonPattern.firstMatch(scriptContent);
      if (match != null) {
        try {
          final jsonStr = match.group(0);
          if (jsonStr != null) {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final puzzle = _parsePuzzleFromJSON(data, day: day, levelId: levelId, date: date);
            if (puzzle != null) return puzzle;
          }
        } catch (e) {
          print('Error parsing JSON pattern: $e');
        }
      }
      
      // Pattern 4: Look for width/height and cell data separately
      // Common pattern: width: 20, height: 15, cells: [...]
      final dimensionsPattern = RegExp(r'(?:width|w)\s*[:=]\s*(\d+)', caseSensitive: false);
      final heightPattern = RegExp(r'(?:height|h)\s*[:=]\s*(\d+)', caseSensitive: false);
      final widthMatch = dimensionsPattern.firstMatch(scriptContent);
      final heightMatch = heightPattern.firstMatch(scriptContent);
      
      if (widthMatch != null && heightMatch != null) {
        final width = int.tryParse(widthMatch.group(1) ?? '');
        final height = int.tryParse(heightMatch.group(1) ?? '');
        if (width != null && height != null) {
          // Try to find cells array
          final cellsPattern = RegExp(r'(?:cells|data)\s*[:=]\s*(\[[\s\S]*?\])', multiLine: true, dotAll: true);
          final cellsMatch = cellsPattern.firstMatch(scriptContent);
          if (cellsMatch != null) {
            try {
              final cellsStr = cellsMatch.group(1);
              if (cellsStr != null) {
                final cells = jsonDecode(cellsStr) as List;
                return _parsePuzzleFromCellsArray(cells, width, height, day: day, levelId: levelId, date: date, maxWalls: extractedMaxWalls);
              }
            } catch (e) {
              print('Error parsing cells array: $e');
            }
          }
        }
      }
      
      // Pattern 5: Look for raw 2D array that spans multiple lines
      // Try to find arrays like: [[0,1,2,...], [3,4,5,...], ...]
      // This is more lenient and tries to match any 2D array structure
      final raw2DArrayPattern = RegExp(r'(\[[\s]*\[[\d\s,\[\]]+\][\s]*\])', multiLine: true, dotAll: true);
      match = raw2DArrayPattern.firstMatch(scriptContent);
      if (match != null) {
        try {
          final arrayStr = match.group(1);
          if (arrayStr != null) {
            // Clean up the string
            final cleaned = arrayStr.replaceAll(RegExp(r'\s+'), ' ');
              final grid = jsonDecode(cleaned) as List;
            if (grid.isNotEmpty && grid[0] is List) {
              return _parsePuzzleFromGridArray(grid, day: day, levelId: levelId, date: date, maxWalls: extractedMaxWalls);
            }
          }
        } catch (e) {
          print('Error parsing raw 2D array: $e');
        }
      }
      
    } catch (e) {
      print('Error extracting from script: $e');
    }
    
    return null;
  }
  
  /// Parses puzzle from a flat cells array with known width/height
  static PuzzleData? _parsePuzzleFromCellsArray(List cells, int width, int height, {String? day, String? levelId, DateTime? date, int? maxWalls}) {
    try {
      final puzzleCells = <int, CellType>{};
      final portals = <int, int>{};
      int? horseRow, horseCol;
      final finalMaxWalls = maxWalls ?? 11; // Default to 11 if not found
      
      for (int i = 0; i < cells.length && i < width * height; i++) {
        final row = i ~/ width;
        final col = i % width;
        final cellValue = cells[i];
        final index = row * width + col;
        
        // Parse cell type from value
        // Common encodings: 0=grass, 1=water, 2=horse, 3=cherry, 4=portal
        if (cellValue is int) {
          switch (cellValue) {
            case 0:
              puzzleCells[index] = CellType.grass;
              break;
            case 1:
              puzzleCells[index] = CellType.water;
              break;
            case 2:
              puzzleCells[index] = CellType.horse;
              horseRow = row;
              horseCol = col;
              break;
            case 3:
              puzzleCells[index] = CellType.cherry;
              break;
            case 4:
            case 5:
              puzzleCells[index] = CellType.portal;
              break;
          }
        } else if (cellValue is String) {
          // String encoding
          switch (cellValue.toUpperCase()) {
            case 'G':
            case 'GRASS':
              puzzleCells[index] = CellType.grass;
              break;
            case 'W':
            case 'WATER':
              puzzleCells[index] = CellType.water;
              break;
            case 'H':
            case 'HORSE':
              puzzleCells[index] = CellType.horse;
              horseRow = row;
              horseCol = col;
              break;
            case 'C':
            case 'CHERRY':
              puzzleCells[index] = CellType.cherry;
              break;
            case 'P':
            case 'PORTAL':
              puzzleCells[index] = CellType.portal;
              break;
          }
        }
      }
      
      // Find portal pairs
      final portalIndices = puzzleCells.entries
          .where((e) => e.value == CellType.portal)
          .map((e) => e.key)
          .toList();
      
      if (portalIndices.length >= 2) {
        // Pair portals
        for (int i = 0; i < portalIndices.length - 1; i += 2) {
          portals[portalIndices[i]] = portalIndices[i + 1];
          portals[portalIndices[i + 1]] = portalIndices[i];
        }
      }
      
      return PuzzleData(
        gridSize: width,
        cells: puzzleCells,
        portals: portals,
        maxWalls: finalMaxWalls,
        horseRow: horseRow ?? height ~/ 2,
        horseCol: horseCol ?? width ~/ 2,
        day: day,
        levelId: levelId,
        date: date,
        puzzleUrl: baseUrl,
      );
    } catch (e) {
      print('Error parsing cells array: $e');
    }
    return null;
  }
  
  /// Parses puzzle from grid element in HTML
  static PuzzleData? _parsePuzzleFromGridElement(html_dom.Element element, html_dom.Document document, {String? day, String? levelId, DateTime? date}) {
    // This is a fallback - would need to inspect actual HTML structure
    // Return null to let the caller use default puzzle
    return null;
  }
  
  /// Parses puzzle from data attributes
  static PuzzleData? _parsePuzzleFromDataAttributes(html_dom.Element element, {String? day, String? levelId, DateTime? date}) {
    try {
      final gridAttr = element.attributes['data-grid'];
      if (gridAttr != null) {
        final grid = jsonDecode(gridAttr) as List;
        return _parsePuzzleFromGridArray(grid, day: day, levelId: levelId, date: date);
      }
    } catch (e) {
      print('Error parsing data attributes: $e');
    }
    return null;
  }
  
  /// Parses puzzle from JSON data
  static PuzzleData? _parsePuzzleFromJSON(Map<String, dynamic> data, {String? day, String? levelId, DateTime? date}) {
    try {
      final gridSize = data['size'] ?? data['gridSize'] ?? 8;
      final grid = data['grid'] as List?;
      final maxWalls = data['maxWalls'] ?? data['walls'] ?? 20;
      
      // Extract metadata from JSON if available
      final jsonDay = data['day']?.toString() ?? day;
      final jsonLevelId = data['levelId']?.toString() ?? data['level']?.toString() ?? levelId;
      
      if (grid != null) {
        return _parsePuzzleFromGridArray(grid, gridSize: gridSize, maxWalls: maxWalls, day: jsonDay, levelId: jsonLevelId, date: date);
      }
    } catch (e) {
      print('Error parsing JSON: $e');
    }
    return null;
  }
  
  /// Parses puzzle from grid array
  static PuzzleData? _parsePuzzleFromGridArray(List grid, {int? gridSize, int? maxWalls, String? day, String? levelId, DateTime? date}) {
    // If maxWalls not provided, try to infer from grid dimensions
    int? inferredMaxWalls = maxWalls;
    if (inferredMaxWalls == null) {
      // Common pattern: smaller grids get fewer walls
      final size = gridSize ?? grid.length;
      if (size <= 8) {
        inferredMaxWalls = 11;
      } else if (size <= 12) {
        inferredMaxWalls = 15;
      } else {
        inferredMaxWalls = 20;
      }
    }
    try {
      final size = gridSize ?? grid.length;
      final cells = <int, CellType>{};
      final portals = <int, int>{};
      int? horseRow, horseCol;
      
      for (int row = 0; row < grid.length; row++) {
        final rowData = grid[row];
        if (rowData is List) {
          for (int col = 0; col < rowData.length; col++) {
            final index = row * size + col;
            final cellValue = rowData[col];
            
            // Parse cell type from value
            // Format depends on how the site stores data
            // Common patterns: 'G'=grass, 'W'=water, 'H'=horse, 'C'=cherry, 'P'=portal
            if (cellValue is String) {
              switch (cellValue.toUpperCase()) {
                case 'G':
                case 'GRASS':
                  cells[index] = CellType.grass;
                  break;
                case 'W':
                case 'WATER':
                  cells[index] = CellType.water;
                  break;
                case 'H':
                case 'HORSE':
                  cells[index] = CellType.horse;
                  horseRow = row;
                  horseCol = col;
                  break;
                case 'C':
                case 'CHERRY':
                  cells[index] = CellType.cherry;
                  break;
                case 'P':
                case 'PORTAL':
                  cells[index] = CellType.portal;
                  break;
                default:
                  cells[index] = CellType.grass;
              }
            } else if (cellValue is int) {
              // Numeric encoding
              switch (cellValue) {
                case 0:
                  cells[index] = CellType.grass;
                  break;
                case 1:
                  cells[index] = CellType.water;
                  break;
                case 2:
                  cells[index] = CellType.horse;
                  horseRow = row;
                  horseCol = col;
                  break;
                case 3:
                  cells[index] = CellType.cherry;
                  break;
                case 4:
                  cells[index] = CellType.portal;
                  break;
                default:
                  cells[index] = CellType.grass;
              }
            }
          }
        }
      }
      
      // Find portal pairs (portals with same ID or consecutive)
      final portalIndices = cells.entries
          .where((e) => e.value == CellType.portal)
          .map((e) => e.key)
          .toList();
      
      if (portalIndices.length >= 2) {
        // Pair portals (assumes pairs)
        for (int i = 0; i < portalIndices.length - 1; i += 2) {
          portals[portalIndices[i]] = portalIndices[i + 1];
          portals[portalIndices[i + 1]] = portalIndices[i];
        }
      }
      
      return PuzzleData(
        gridSize: size,
        cells: cells,
        portals: portals,
        maxWalls: inferredMaxWalls,
        horseRow: horseRow ?? 2,
        horseCol: horseCol ?? 2,
        day: day,
        levelId: levelId,
        date: date,
        puzzleUrl: baseUrl,
      );
    } catch (e) {
      print('Error parsing grid array: $e');
    }
    return null;
  }
  
  /// Creates a default puzzle when crawling fails
  static PuzzleData createDefaultPuzzle({String? day, String? levelId, DateTime? date}) {
    print('DEBUG: ⚠️  Creating DEFAULT puzzle (hardcoded 8x8)');
    final cells = <int, CellType>{};
    const size = 8;
    
    // Default layout
    cells[1 * size + 1] = CellType.water; // Water at (1,1)
    cells[2 * size + 2] = CellType.horse; // Horse at (2,2)
    cells[3 * size + 3] = CellType.cherry; // Cherry at (3,3)
    cells[0 * size + 3] = CellType.portal; // Portal at (0,3)
    cells[7 * size + 4] = CellType.portal; // Portal at (7,4)
    
    final portals = <int, int>{
      0 * size + 3: 7 * size + 4,
      7 * size + 4: 0 * size + 3,
    };
    
    return PuzzleData(
      gridSize: size,
      cells: cells,
      portals: portals,
      maxWalls: 20,
      horseRow: 2,
      horseCol: 2,
      day: day ?? 'Practice',
      levelId: levelId ?? 'Default',
      date: date ?? DateTime.now(),
      puzzleUrl: baseUrl,
    );
  }
}

