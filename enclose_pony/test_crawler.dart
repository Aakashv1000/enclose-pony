import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final response = await http.get(Uri.parse('https://enclose.horse'));
  final html = response.body;
  
  // Try to extract puzzle ID
  final pattern = RegExp(r'__DAILY_LEVELS__\s*=\s*(\[)', multiLine: true);
  final match = pattern.firstMatch(html);
  
  if (match != null) {
    print('Found pattern at position: ${match.start}');
    final scriptContent = html.substring(match.start);
    
    // Find the array
    int bracketCount = 0;
    int startIndex = match.start + match.group(0)!.length - 1;
    int endIndex = startIndex;
    
    for (int i = startIndex; i < scriptContent.length && i < startIndex + 5000; i++) {
      if (scriptContent[i] == '[') bracketCount++;
      if (scriptContent[i] == ']') {
        bracketCount--;
        if (bracketCount == 0) {
          endIndex = i + 1;
          break;
        }
      }
    }
    
    if (endIndex > startIndex) {
      final jsonStr = html.substring(startIndex, endIndex);
      print('Extracted JSON (first 200 chars): ${jsonStr.substring(0, jsonStr.length > 200 ? 200 : jsonStr.length)}');
      
      try {
        final levels = jsonDecode(jsonStr) as List;
        if (levels.isNotEmpty) {
          final todayPuzzle = levels[0] as Map<String, dynamic>;
          print('Today puzzle ID: ${todayPuzzle['id']}');
          print('Today puzzle name: ${todayPuzzle['name']}');
        }
      } catch (e) {
        print('Error parsing: $e');
      }
    }
  } else {
    print('Pattern not found');
  }
}
