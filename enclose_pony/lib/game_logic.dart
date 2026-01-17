// Game logic for Enclose Pony - Phase 3: Enclosure Detection
// Separated from UI for testability

/// Determines which cells are reachable from the edges of the grid.
/// Cells that are not reachable are considered enclosed.
/// 
/// Rules:
/// - Can't move through walls
/// - Can't move through water
/// - Can move on grass, horse, and cherry cells
/// - Starts from all edge cells
/// 
/// Returns a Set of cell indices that are reachable from edges.
Set<int> floodFillFromEdges({
  required int gridSize,
  required Set<int> walls,
  required bool Function(int row, int col) isWater,
  Map<int, int> portals = const {},
}) {
  final reachable = <int>{};
  final visited = <int>{};
  final queue = <int>[];

  // Helper to convert row/col to index
  int getIndex(int row, int col) => row * gridSize + col;

  // Helper to check if a cell can be traversed
  bool canTraverse(int row, int col) {
    // Can't go through walls
    final index = getIndex(row, col);
    if (walls.contains(index)) {
      return false;
    }
    // Can't go through water
    if (isWater(row, col)) {
      return false;
    }
    return true;
  }

  // Helper to get neighbors (up, down, left, right - no diagonals) + portals
  List<int> getNeighbors(int row, int col) {
    final neighbors = <int>[];
    final currentIndex = getIndex(row, col);
    
    // Up
    if (row > 0 && canTraverse(row - 1, col)) {
      neighbors.add(getIndex(row - 1, col));
    }
    // Down
    if (row < gridSize - 1 && canTraverse(row + 1, col)) {
      neighbors.add(getIndex(row + 1, col));
    }
    // Left
    if (col > 0 && canTraverse(row, col - 1)) {
      neighbors.add(getIndex(row, col - 1));
    }
    // Right
    if (col < gridSize - 1 && canTraverse(row, col + 1)) {
      neighbors.add(getIndex(row, col + 1));
    }
    
    // Portal connections
    if (portals.containsKey(currentIndex)) {
      final connectedPortal = portals[currentIndex]!;
      neighbors.add(connectedPortal);
    }
    
    return neighbors;
  }

  // Start flood fill from all edge cells
  // Top row
  for (int col = 0; col < gridSize; col++) {
    final index = getIndex(0, col);
    if (canTraverse(0, col) && !visited.contains(index)) {
      queue.add(index);
      visited.add(index);
      reachable.add(index);
    }
  }
  // Bottom row
  for (int col = 0; col < gridSize; col++) {
    final index = getIndex(gridSize - 1, col);
    if (canTraverse(gridSize - 1, col) && !visited.contains(index)) {
      queue.add(index);
      visited.add(index);
      reachable.add(index);
    }
  }
  // Left column
  for (int row = 0; row < gridSize; row++) {
    final index = getIndex(row, 0);
    if (canTraverse(row, 0) && !visited.contains(index)) {
      queue.add(index);
      visited.add(index);
      reachable.add(index);
    }
  }
  // Right column
  for (int row = 0; row < gridSize; row++) {
    final index = getIndex(row, gridSize - 1);
    if (canTraverse(row, gridSize - 1) && !visited.contains(index)) {
      queue.add(index);
      visited.add(index);
      reachable.add(index);
    }
  }

  // BFS from all edge cells
  while (queue.isNotEmpty) {
    final currentIndex = queue.removeAt(0);
    final row = currentIndex ~/ gridSize;
    final col = currentIndex % gridSize;

    final neighbors = getNeighbors(row, col);
    for (final neighborIndex in neighbors) {
      if (!visited.contains(neighborIndex)) {
        visited.add(neighborIndex);
        reachable.add(neighborIndex);
        queue.add(neighborIndex);
      }
    }
  }

  return reachable;
}

/// Determines which cells are enclosed (not reachable from edges).
/// Returns a Set of cell indices that are enclosed.
Set<int> getEnclosedCells({
  required int gridSize,
  required Set<int> walls,
  required bool Function(int row, int col) isWater,
  Map<int, int> portals = const {},
}) {
  final reachable = floodFillFromEdges(
    gridSize: gridSize,
    walls: walls,
    isWater: isWater,
    portals: portals,
  );

  // All cells that exist but are not reachable are enclosed
  final allCells = <int>{};
  for (int row = 0; row < gridSize; row++) {
    for (int col = 0; col < gridSize; col++) {
      final index = row * gridSize + col;
      // Don't count walls or water as enclosed
      if (!walls.contains(index) && !isWater(row, col)) {
        allCells.add(index);
      }
    }
  }

  return allCells.difference(reachable);
}

/// Finds the escape path from horse position to the nearest edge cell.
/// Returns a list of cell indices representing the path, or empty list if no path exists.
List<int> findEscapePath({
  required int gridSize,
  required int horseRow,
  required int horseCol,
  required Set<int> walls,
  required bool Function(int row, int col) isWater,
  Map<int, int> portals = const {},
}) {
  final path = <int>[];
  final visited = <int>{};
  final queue = <int>[];
  final parent = <int, int>{};

  int getIndex(int row, int col) => row * gridSize + col;

  bool canTraverse(int row, int col) {
    final index = getIndex(row, col);
    if (walls.contains(index)) return false;
    if (isWater(row, col)) return false;
    return true;
  }

  List<int> getNeighbors(int row, int col) {
    final neighbors = <int>[];
    if (row > 0 && canTraverse(row - 1, col)) {
      neighbors.add(getIndex(row - 1, col));
    }
    if (row < gridSize - 1 && canTraverse(row + 1, col)) {
      neighbors.add(getIndex(row + 1, col));
    }
    if (col > 0 && canTraverse(row, col - 1)) {
      neighbors.add(getIndex(row, col - 1));
    }
    if (col < gridSize - 1 && canTraverse(row, col + 1)) {
      neighbors.add(getIndex(row, col + 1));
    }
    
    // Portal connections
    final currentIndex = getIndex(row, col);
    if (portals.containsKey(currentIndex)) {
      final connectedPortal = portals[currentIndex]!;
      neighbors.add(connectedPortal);
    }
    
    return neighbors;
  }

  bool isEdgeCell(int row, int col) {
    return row == 0 || row == gridSize - 1 || col == 0 || col == gridSize - 1;
  }

  // Start BFS from horse position
  final horseIndex = getIndex(horseRow, horseCol);
  if (!canTraverse(horseRow, horseCol)) return path;

  queue.add(horseIndex);
  visited.add(horseIndex);
  parent[horseIndex] = -1; // Sentinel value

  int? targetIndex;

  while (queue.isNotEmpty) {
    final currentIndex = queue.removeAt(0);
    final row = currentIndex ~/ gridSize;
    final col = currentIndex % gridSize;

    // Check if we reached an edge
    if (isEdgeCell(row, col)) {
      targetIndex = currentIndex;
      break;
    }

    final neighbors = getNeighbors(row, col);
    for (final neighborIndex in neighbors) {
      if (!visited.contains(neighborIndex)) {
        visited.add(neighborIndex);
        parent[neighborIndex] = currentIndex;
        queue.add(neighborIndex);
      }
    }
  }

  // Reconstruct path if target found (path is from edge to horse, so we reverse it)
  if (targetIndex != null) {
    int? current = targetIndex;
    while (current != null && current != -1) {
      path.add(current);
      current = parent[current];
    }
  }

  return path.reversed.toList(); // Return path from horse to edge
}

