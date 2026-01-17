import 'package:flutter/material.dart';
import 'package:enclose_pony/game_logic.dart';

void main() {
  runApp(const EnclosePonyApp());
}

class EnclosePonyApp extends StatelessWidget {
  const EnclosePonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enclose Pony',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GridDisplayScreen(),
    );
  }
}

// Cell types enum
enum CellType {
  grass,
  water,
  horse,
  cherry,
}

// Grid Display Screen - Phase 4: Check Enclosure Button!
class GridDisplayScreen extends StatefulWidget {
  const GridDisplayScreen({super.key});

  @override
  State<GridDisplayScreen> createState() => _GridDisplayScreenState();
}

class _GridDisplayScreenState extends State<GridDisplayScreen> {
  // Hardcoded 8x8 grid
  // Cell (0,0) = grass
  // Cell (1,1) = water
  // Cell (2,2) = horse
  // Cell (3,3) = cherry
  static const int gridSize = 8;
  
  // Track which cells have walls placed
  Set<int> walls = {};
  
  // Limited walls - you start with a certain number
  static const int maxWalls = 20;
  int remainingWalls = maxWalls;
  
  // Track enclosed cells (computed via flood fill)
  Set<int> _enclosedCells = {};
  
  // Track if horse is enclosed (win condition)
  bool? _horseEnclosed; // null = not checked, true = win, false = fail
  
  // Score tracking
  int? _score; // null = not calculated, otherwise the final score
  
  CellType getCellType(int row, int col) {
    // Hardcoded cells as specified
    if (row == 2 && col == 2) {
      return CellType.horse;
    }
    if (row == 1 && col == 1) {
      return CellType.water;
    }
    if (row == 3 && col == 3) {
      return CellType.cherry;
    }
    // Default to grass for all other cells
    return CellType.grass;
  }

  Color getCellColor(CellType cellType) {
    switch (cellType) {
      case CellType.grass:
        return Colors.green;
      case CellType.water:
        return Colors.blue;
      case CellType.horse:
        return Colors.brown;
      case CellType.cherry:
        return Colors.red;
    }
  }
  
  int getCellIndex(int row, int col) {
    return row * gridSize + col;
  }
  
  bool hasWall(int row, int col) {
    final index = getCellIndex(row, col);
    return walls.contains(index);
  }
  
  bool isWater(int row, int col) {
    return getCellType(row, col) == CellType.water;
  }
  
  bool isEnclosed(int row, int col) {
    final index = getCellIndex(row, col);
    return _enclosedCells.contains(index);
  }
  
  void toggleWall(int row, int col) {
    final cellType = getCellType(row, col);
    // Only allow placing walls on grass tiles
    if (cellType != CellType.grass) {
      return;
    }
    
    final index = getCellIndex(row, col);
    setState(() {
      if (walls.contains(index)) {
        // Remove wall
        walls.remove(index);
        remainingWalls++;
      } else {
        // Place wall if we have remaining walls
        if (remainingWalls > 0) {
          walls.add(index);
          remainingWalls--;
        }
      }
      // Reset enclosure check when walls change
      _enclosedCells = {};
      _horseEnclosed = null;
      _score = null;
    });
  }
  
  void checkEnclosure() {
    setState(() {
      // Run flood fill to find enclosed cells
      _enclosedCells = getEnclosedCells(
        gridSize: gridSize,
        walls: walls,
        isWater: isWater,
      );
      
      // Check if horse is enclosed
      final horseIndex = getCellIndex(2, 2); // Horse is at (2, 2)
      _horseEnclosed = _enclosedCells.contains(horseIndex);
      
      // Calculate score only if horse is enclosed (win condition)
      if (_horseEnclosed == true) {
        _score = calculateScore();
      } else {
        _score = null; // No score if horse is not enclosed
      }
    });
  }
  
  int calculateScore() {
    // Base score = number of enclosed cells
    int baseScore = _enclosedCells.length;
    
    // Bonus: +3 points for each enclosed cherry
    int cherryBonus = 0;
    const cherryBonusPerCherry = 3;
    
    // Count how many cherries are enclosed
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (getCellType(row, col) == CellType.cherry) {
          final index = getCellIndex(row, col);
          if (_enclosedCells.contains(index)) {
            cherryBonus += cherryBonusPerCherry;
          }
        }
      }
    }
    
    return baseScore + cherryBonus;
  }
  
  int getHorseRow() {
    // Find horse position - hardcoded at (2, 2) for now
    return 2;
  }
  
  int getHorseCol() {
    return 2;
  }
  
  String _getScoreBreakdown() {
    if (_score == null || _enclosedCells.isEmpty) {
      return '';
    }
    
    int baseScore = _enclosedCells.length;
    int cherryCount = 0;
    int cherryBonus = 0;
    
    // Count enclosed cherries
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (getCellType(row, col) == CellType.cherry) {
          final index = getCellIndex(row, col);
          if (_enclosedCells.contains(index)) {
            cherryCount++;
          }
        }
      }
    }
    cherryBonus = cherryCount * 3;
    
    if (cherryCount > 0) {
      return 'Base: $baseScore + Cherry bonus: $cherryCount × 3 = $cherryBonus';
    } else {
      return 'Base: $baseScore (no cherries enclosed)';
    }
  }

  Widget buildCell(int row, int col) {
    final cellType = getCellType(row, col);
    var color = getCellColor(cellType);
    final isWall = hasWall(row, col);
    final enclosed = isEnclosed(row, col);
    
    // If cell is enclosed and it's grass/horse/cherry, tint it yellow
    if (enclosed && cellType != CellType.water) {
      // Mix yellow with the base color to show enclosure
      color = Colors.yellow.withValues(alpha: 0.7);
    }
    
    // For cherry, show a red dot (circle)
    if (cellType == CellType.cherry) {
      return GestureDetector(
        onTap: () => toggleWall(row, col),
        child: Container(
          decoration: BoxDecoration(
            color: enclosed ? Colors.yellow.withValues(alpha: 0.7) : Colors.green, // Background is grass
            border: isWall
                ? Border.all(color: Colors.black, width: 4)
                : null,
          ),
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red, // Cherry stays red
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }
    
    // For other cells, show colored square with optional wall
    return GestureDetector(
      onTap: () => toggleWall(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: isWall
              ? Border.all(color: Colors.black, width: 4)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enclose Pony'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Walls: $remainingWalls/$maxWalls',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_score != null)
                    Text(
                      'Score: $_score',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      'Score: 0',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridSize,
                    crossAxisSpacing: 2.0,
                    mainAxisSpacing: 2.0,
                  ),
                  itemCount: gridSize * gridSize,
                  itemBuilder: (context, index) {
                    final row = index ~/ gridSize;
                    final col = index % gridSize;
                    return buildCell(row, col);
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: checkEnclosure,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tap grass tiles to place walls',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
                if (_enclosedCells.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Yellow = Enclosed cells (${_enclosedCells.length} cells)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                if (_horseEnclosed != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Column(
                      children: [
                        // Win/Lose state
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: _horseEnclosed! ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            _horseEnclosed!
                                ? '✓ WIN! Horse is enclosed!'
                                : '✗ FAIL! Horse is NOT enclosed',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Score display (only if win)
                        if (_horseEnclosed! && _score != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Score: $_score',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getScoreBreakdown(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

