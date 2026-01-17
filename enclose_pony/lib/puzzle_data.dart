// Puzzle data model for Enclose Pony

class PuzzleData {
  final int gridSize;
  final Map<int, CellType> cells; // Maps cell index to cell type
  final Map<int, int> portals; // Maps portal index to connected portal index
  final int maxWalls;
  final int horseRow;
  final int horseCol;
  
  // Puzzle metadata
  final String? day; // Day number (e.g., "Day 1", "Day 42")
  final String? levelId; // Level identifier
  final DateTime? date; // Puzzle date
  final String? puzzleUrl; // URL where puzzle was fetched from
  final String? puzzleName; // Puzzle name (e.g., "Dual Portals")
  final String? creatorName; // Creator name (e.g., "Shivers")

  PuzzleData({
    required this.gridSize,
    required this.cells,
    required this.portals,
    required this.maxWalls,
    required this.horseRow,
    required this.horseCol,
    this.day,
    this.levelId,
    this.date,
    this.puzzleUrl,
    this.puzzleName,
    this.creatorName,
  });

  CellType getCellType(int row, int col) {
    final index = row * gridSize + col;
    return cells[index] ?? CellType.grass;
  }

  int getCellIndex(int row, int col) => row * gridSize + col;
}

enum CellType {
  grass,
  water,
  horse,
  cherry,
  portal,
}

