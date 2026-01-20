import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:enclose_pony/game_logic.dart' show getEnclosedCells, findEscapePath;
import 'package:enclose_pony/puzzle_data.dart' show PuzzleData, CellType;
import 'package:enclose_pony/puzzle_crawler.dart';

void main() {
  runApp(const EnclosePonyApp());
}

class EnclosePonyApp extends StatelessWidget {
  const EnclosePonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enclose Pony',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF7ED321), // Green grass background
        fontFamily: null, // Use system default for more handwritten look
      ),
      home: const GridDisplayScreen(),
    );
  }
}

// Custom painter for animated water
class PortalConnectionPainter extends CustomPainter {
  final Map<int, int> portals;
  final Map<int, int> portalColors;
  final int? hoveringPortalIndex; // Only draw line for hovered portal pair
  final int gridSize;
  final double cellMargin;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double containerPadding;
  
  PortalConnectionPainter({
    required this.portals,
    required this.portalColors,
    this.hoveringPortalIndex, // Null means no lines should be drawn
    required this.gridSize,
    required this.cellMargin,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.containerPadding,
  });
  
  // Portal colors - different color for each pair
  static const List<Color> _portalPairColors = [
    Color(0xFF87CEEB), // Light blue/sky blue - Pair 1
    Color(0xFF9B59B6), // Purple - Pair 2
    Color(0xFFE67E22), // Orange - Pair 3
    Color(0xFF1ABC9C), // Teal - Pair 4
    Color(0xFFE74C3C), // Red - Pair 5
    Color(0xFFF39C12), // Yellow - Pair 6
    Color(0xFF3498DB), // Blue - Pair 7
    Color(0xFF16A085), // Green - Pair 8
  ];
  
  @override
  void paint(Canvas canvas, Size size) {
    // Only draw if hovering over a portal
    if (portals.isEmpty || hoveringPortalIndex == null) return;
    
    // Find the connected portal for the hovered one
    final portal1Index = hoveringPortalIndex!;
    final portal2Index = portals[portal1Index];
    
    if (portal2Index == null) return; // No connection found
    
    // Grid now has no spacing between cells, so cell size is simply width/gridSize
    // Each cell has margin of 1px on all sides
    final cellSize = size.width / gridSize;
      
    // Get portal positions
    final portal1Row = portal1Index ~/ gridSize;
    final portal1Col = portal1Index % gridSize;
    final portal2Row = portal2Index ~/ gridSize;
    final portal2Col = portal2Index % gridSize;
    
    // Calculate center positions of portals
    // Cell centers are at: col * cellSize + cellSize/2 (accounting for 1px margin)
    final portal1X = portal1Col * cellSize + cellSize / 2;
    final portal1Y = portal1Row * cellSize + cellSize / 2;
    final portal2X = portal2Col * cellSize + cellSize / 2;
    final portal2Y = portal2Row * cellSize + cellSize / 2;
    
    final portal1Center = Offset(portal1X, portal1Y);
    final portal2Center = Offset(portal2X, portal2Y);
    
    // Get color for this portal pair
    final colorId = portalColors[portal1Index] ?? 0;
    final lineColor = _portalPairColors[colorId % _portalPairColors.length];
    
    // Draw line between portals with thicker, more visible line
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.8)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Also draw a subtle shadow for better visibility
    final shadowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawLine(portal1Center, portal2Center, shadowPaint);
    canvas.drawLine(portal1Center, portal2Center, paint);
  }
  
  @override
  bool shouldRepaint(PortalConnectionPainter oldDelegate) {
    // Only repaint when hover state changes or grid size changes
    // Don't repaint for Map changes (Maps are compared by reference, not content)
    return oldDelegate.hoveringPortalIndex != hoveringPortalIndex ||
           oldDelegate.gridSize != gridSize;
  }
}

class WaterPainter extends CustomPainter {
  final Animation<double> animation;
  
  WaterPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..style = PaintingStyle.fill;

    final wavePaint = Paint()
      ..color = const Color(0xFF5BA3F5).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Base water color
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(8)),
      paint,
    );

    // Animated waves
    final waveHeight = 3.0;
    final path = Path();
    for (double x = 0; x < size.width; x += 5) {
      final y = size.height / 2 + 
          math.sin((x / size.width * 2 * math.pi) + (animation.value * 2 * math.pi)) * waveHeight;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(WaterPainter oldDelegate) => true;
}

// Custom painter for animated grass background with diagonal lines and shades
class GrassBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  
  GrassBackgroundPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Base dark green background
    final basePaint = Paint()
      ..color = const Color(0xFF5BA318)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);
    
    // Add diagonal line pattern with varying shades
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Create diagonal lines pattern
    final spacing = 20.0;
    final lineOffset = animation.value * spacing; // Animate the lines
    
    // Draw diagonal lines going from top-left to bottom-right
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      final x1 = i + lineOffset;
      final y1 = 0.0;
      final x2 = i + lineOffset - size.height;
      final y2 = size.height;
      
      // Vary opacity for subtle effect
      final opacity = 0.1 + (math.sin(i / 50 + animation.value * 2 * math.pi) + 1) / 2 * 0.1;
      linePaint.color = const Color(0xFF7ED321).withValues(alpha: opacity);
      
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }
    
    // Add some lighter green patches for texture
    final patchPaint = Paint()
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent pattern
    
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 30 + random.nextDouble() * 50;
      
      // Animate patches slightly
      final animOffset = math.sin(animation.value * 2 * math.pi + i) * 5;
      
      final gradient = RadialGradient(
        colors: [
          const Color(0xFF7ED321).withValues(alpha: 0.15 + animOffset * 0.01),
          const Color(0xFF5BA318).withValues(alpha: 0.0),
        ],
      );
      
      patchPaint.shader = gradient.createShader(
        Rect.fromCircle(center: Offset(x, y), radius: radius),
      );
      
      canvas.drawCircle(Offset(x, y), radius, patchPaint);
    }
  }

  @override
  bool shouldRepaint(GrassBackgroundPainter oldDelegate) => true;
}

// Grid Display Screen - Beautiful UI Version!
class GridDisplayScreen extends StatefulWidget {
  const GridDisplayScreen({super.key});

  @override
  State<GridDisplayScreen> createState() => _GridDisplayScreenState();
}

class _GridDisplayScreenState extends State<GridDisplayScreen> with TickerProviderStateMixin {
  // Puzzle data
  PuzzleData? _puzzleData;
  bool _isLoadingPuzzle = true;
  List<Map<String, dynamic>> _allPuzzles = []; // All available puzzles from __DAILY_LEVELS__
  Map<String, dynamic>? _selectedPuzzleMetadata; // Currently selected puzzle metadata
  
  // Grid size (from puzzle or default)
  int get gridSize => _puzzleData?.gridSize ?? 8;
  
  // Track which cells have walls placed
  Set<int> walls = {};
  
  // Limited walls (from puzzle or default)
  int get maxWalls => _puzzleData?.maxWalls ?? 20;
  int remainingWalls = 20;
  
  // Horse position (from puzzle or default)
  int get horseRow => _puzzleData?.horseRow ?? 2;
  int get horseCol => _puzzleData?.horseCol ?? 2;
  
  // Track enclosed cells
  Set<int> _enclosedCells = {};
  
  // Track game state
  bool? _horseEnclosed;
  int? _score;
  List<int> _escapePath = []; // Path from horse to edge when not enclosed
  bool _showTutorial = true; // Show tutorial on first load
  bool _isHoveringHorse = false; // Track if hovering over horse
  String? _currentHorsePun; // Current horse pun to display
  double _currentCellSize = 60.0; // Current cell size for icon scaling
  bool _hasSubmitted = false; // Track if player has submitted
  int? _hoveringPortalIndex; // Track which portal is being hovered
  Map<int, int> _portalColors = {}; // Map portal index to color ID for color-coding
  
  // Horse puns collection
  static const List<String> _horsePuns = [
    'Neigh! I can escape through here! 🐴',
    'Hay! Watch me break free! 🌾',
    'Hold your horses! I see a way out! 🏃',
    'Hoof it! I\'m heading this way! 👟',
    'Saddle up! I\'m getting away! 🐎',
    'Canter believe it? I\'m escaping! 💨',
    'Giddy up! I found an exit! 🚪',
    'Mane event: my escape route! 🦁',
    'Stall-ing? Not me! I\'m outta here! ⚡',
    'Trot along this path to freedom! 🛤️',
    'Gallop away to victory! 🏁',
    'Neigh problem! I see the exit! ✅',
  ];
  
  // Portal pairs - maps portal index to connected portal index
  Map<int, int> _portals = {};
  
  // Random tip for tutorial
  late String _currentTip;
  
  // List of tips
  static const List<String> _tips = [
    'Hover or tap the horse to see how he\'ll escape!',
    'Try to enclose cherries for bonus points!',
    'Portals can help you create unexpected enclosures!',
    'Water blocks movement - use it to your advantage!',
    'Plan your walls carefully - you only have one chance to submit!',
    'Bigger enclosures mean higher scores!',
    'The horse can teleport through portals instantly!',
    'Think about the escape path before placing walls!',
    'Enclosed cherries are worth +3 points each!',
    'Use walls strategically to create the largest pen!',
  ];
  
  // Animation controllers
  late AnimationController _waterAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _pathAnimationController;
  late AnimationController _tutorialAnimationController;
  late Map<int, AnimationController> _wallAnimationControllers;

  @override
  void initState() {
    super.initState();
    _waterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pathAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _tutorialAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _wallAnimationControllers = {};
    
    // Random tip selection
    final random = math.Random();
    _currentTip = _tips[random.nextInt(_tips.length)];
    
    // Load all puzzles and today's puzzle
    _loadAllPuzzles();
    _loadPuzzle();
    
    // Show tutorial on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tutorialAnimationController.forward();
    });
  }
  
  Future<void> _loadAllPuzzles() async {
    try {
      final allPuzzles = await PuzzleCrawler.fetchAllPuzzles();
      setState(() {
        _allPuzzles = allPuzzles;
      });
    } catch (e) {
      print('Error loading all puzzles: $e');
    }
  }
  
  Future<void> _loadPuzzle({Map<String, dynamic>? puzzleMetadata}) async {
    print('=== DEBUG: _loadPuzzle() called ===');
    setState(() {
      _isLoadingPuzzle = true;
    });
    
    try {
      PuzzleData? puzzle;
      
      if (puzzleMetadata != null) {
        // Load specific puzzle
        final puzzleId = puzzleMetadata['id'] as String?;
        final dayNumber = puzzleMetadata['dayNumber'] as int?;
        final puzzleDate = puzzleMetadata['date'] as String?;
        
        if (puzzleId != null) {
          puzzle = await PuzzleCrawler.fetchPuzzleById(puzzleId, dayNumber: dayNumber, puzzleDate: puzzleDate);
        }
        setState(() {
          _selectedPuzzleMetadata = puzzleMetadata;
        });
      } else {
        // Load today's puzzle
        print('DEBUG: Calling PuzzleCrawler.fetchTodayPuzzle()...');
        puzzle = await PuzzleCrawler.fetchTodayPuzzle();
      }
      
      if (puzzle != null) {
        print('DEBUG: ✅ Puzzle returned from fetchTodayPuzzle');
        print('DEBUG:    - puzzle is NOT null');
        print('DEBUG:    - levelId: ${puzzle.levelId ?? 'null'}');
        print('DEBUG:    - gridSize: ${puzzle.gridSize}');
        print('DEBUG:    - maxWalls: ${puzzle.maxWalls}');
        print('DEBUG:    - horseRow: ${puzzle.horseRow}, horseCol: ${puzzle.horseCol}');
        print('DEBUG: Setting state with real puzzle data...');
        setState(() {
          _puzzleData = puzzle!;
          _portals = Map.from(puzzle!.portals);
          remainingWalls = puzzle!.maxWalls;
          walls.clear(); // Clear any existing walls when loading new puzzle
          _isLoadingPuzzle = false;
          _initializePortalColors(); // Color-code portals by pairs
        });
        print('DEBUG: ✅ State updated with puzzle data');
        print('DEBUG:    - _puzzleData is now: ${_puzzleData != null ? "NOT null" : "null"}');
        print('DEBUG:    - gridSize getter: $gridSize');
        print('DEBUG:    - maxWalls getter: $maxWalls');
      } else {
        print('DEBUG: ❌ Puzzle is NULL from fetchTodayPuzzle');
        print('DEBUG: ⚠️  Falling back to DEFAULT puzzle');
        // Use default puzzle if crawling fails
        setState(() {
          _puzzleData = PuzzleCrawler.createDefaultPuzzle();
          _portals = Map.from(_puzzleData!.portals);
          remainingWalls = _puzzleData!.maxWalls;
          walls.clear(); // Clear any existing walls when loading new puzzle
          _isLoadingPuzzle = false;
          _initializePortalColors(); // Color-code portals by pairs
        });
        print('DEBUG: ⚠️  State set with DEFAULT puzzle');
        print('DEBUG:    - _puzzleData gridSize: ${_puzzleData?.gridSize}');
      }
    } catch (e, stackTrace) {
      print('DEBUG: ❌ EXCEPTION in _loadPuzzle: $e');
      print('DEBUG: Stack trace: $stackTrace');
      // Use default puzzle on error
      setState(() {
        _puzzleData = PuzzleCrawler.createDefaultPuzzle();
        _portals = Map.from(_puzzleData!.portals);
        remainingWalls = _puzzleData!.maxWalls;
        walls.clear(); // Clear any existing walls when loading new puzzle
        _isLoadingPuzzle = false;
      });
      print('DEBUG: ⚠️  Exception caught, state set with DEFAULT puzzle');
    }
    print('=== DEBUG: _loadPuzzle() completed ===');
  }
  
  // Track which tab is selected in tutorial
  int _tutorialTabIndex = 0;

  @override
  void dispose() {
    _waterAnimationController.dispose();
    _pulseAnimationController.dispose();
    _pathAnimationController.dispose();
    _tutorialAnimationController.dispose();
    for (var controller in _wallAnimationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void closeTutorial() {
    _tutorialAnimationController.reverse().then((_) {
      setState(() {
        _showTutorial = false;
      });
    });
  }
  
  void resetWalls() {
    setState(() {
      walls = {};
      remainingWalls = maxWalls;
      _enclosedCells = {};
      _horseEnclosed = null;
      _score = null;
      _escapePath = [];
      _isHoveringHorse = false;
      _currentHorsePun = null;
      _hasSubmitted = false;
      _hoveringPortalIndex = null;
      for (var controller in _wallAnimationControllers.values) {
        controller.dispose();
      }
      _wallAnimationControllers = {};
    });
  }
  
  void retryGame() {
    setState(() {
      walls = {};
      remainingWalls = maxWalls;
      _enclosedCells = {};
      _horseEnclosed = null;
      _score = null;
      _escapePath = [];
      _isHoveringHorse = false;
      _currentHorsePun = null;
      _hasSubmitted = false;
      _hoveringPortalIndex = null;
      // Select new random tip
      final random = math.Random();
      _currentTip = _tips[random.nextInt(_tips.length)];
      for (var controller in _wallAnimationControllers.values) {
        controller.dispose();
      }
      _wallAnimationControllers = {};
    });
  }

  CellType getCellType(int row, int col) {
    if (_puzzleData != null) {
      return _puzzleData!.getCellType(row, col);
    }
    // Fallback to default (shouldn't happen after load)
    if (row == 2 && col == 2) return CellType.horse;
    if (row == 1 && col == 1) return CellType.water;
    if (row == 3 && col == 3) return CellType.cherry;
    if ((row == 0 && col == 3) || (row == 7 && col == 4)) return CellType.portal;
    return CellType.grass;
  }
  
  int? getConnectedPortal(int index) {
    return _portals[index];
  }
  
  bool isPortal(int row, int col) {
    return getCellType(row, col) == CellType.portal;
  }
  
  int getCellIndex(int row, int col) => row * gridSize + col;
  bool hasWall(int row, int col) => walls.contains(getCellIndex(row, col));
  bool isWater(int row, int col) => getCellType(row, col) == CellType.water;
  bool isEnclosed(int row, int col) => _enclosedCells.contains(getCellIndex(row, col));

  // Beautiful color scheme - tiles on green background
  Color _getGrassColor(bool enclosed) {
    if (enclosed) {
      return const Color(0xFFF4D03F); // Golden yellow for enclosed tiles
    }
    return const Color(0xFF8ED632); // Slightly brighter green for tiles
  }

  Color _getWaterColor() => const Color(0xFF4A90E2);

  void toggleWall(int row, int col) {
    final cellType = getCellType(row, col);
    if (cellType != CellType.grass) return;
    
    final index = getCellIndex(row, col);
    setState(() {
      if (walls.contains(index)) {
        walls.remove(index);
        remainingWalls++;
        _wallAnimationControllers[index]?.reverse();
      } else {
        if (remainingWalls > 0) {
          walls.add(index);
          remainingWalls--;
          
          // Create animation for wall placement
          final controller = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 300),
          );
          _wallAnimationControllers[index] = controller;
          controller.forward();
        }
      }
      _enclosedCells = {};
      _horseEnclosed = null;
      _score = null;
      _escapePath = [];
    });
  }

  void checkEnclosure() {
    if (_hasSubmitted) return; // Only allow one submission
    
    setState(() {
      _hasSubmitted = true;
      _isHoveringHorse = false; // Stop showing hover path
      
      _enclosedCells = getEnclosedCells(
        gridSize: gridSize,
        walls: walls,
        isWater: isWater,
        portals: _portals,
      );
      
      final horseIndex = getCellIndex(horseRow, horseCol);
      _horseEnclosed = _enclosedCells.contains(horseIndex);
      
      if (_horseEnclosed == true) {
        _score = calculateScore();
        _escapePath = [];
      } else {
        _score = null;
        // Find escape path
        _escapePath = findEscapePath(
          gridSize: gridSize,
          horseRow: horseRow,
          horseCol: horseCol,
          walls: walls,
          isWater: isWater,
          portals: _portals,
        );
      }
    });
  }
  
  void onHorseHover(bool isHovering) {
    if (_hasSubmitted) return; // Don't show hover path after submission
    
    setState(() {
      _isHoveringHorse = isHovering;
      _hoveringPortalIndex = null; // Clear portal hover when hovering horse
      
      if (isHovering) {
        // Select random horse pun
        final random = math.Random();
        _currentHorsePun = _horsePuns[random.nextInt(_horsePuns.length)];
        
        // Calculate escape path on hover (only one path)
        _escapePath = findEscapePath(
          gridSize: gridSize,
          horseRow: horseRow,
          horseCol: horseCol,
          walls: walls,
          isWater: isWater,
          portals: _portals,
        );
      } else {
        // Only clear escape path if not submitted (to preserve submission path)
        if (!_hasSubmitted) {
          _escapePath = [];
        }
        _currentHorsePun = null;
      }
    });
  }
  
  void onPortalHover(int? portalIndex) {
    // Update state for mouse hover (desktop) - don't override tap state
    // Only update if state is actually different
    if (_hoveringPortalIndex != portalIndex) {
      setState(() {
        _hoveringPortalIndex = portalIndex;
        if (portalIndex != null) {
          _isHoveringHorse = false; // Clear horse hover when hovering portal
          _escapePath = [];
          _currentHorsePun = null;
        }
      });
    }
  }
  
  void _initializePortalColors() {
    _portalColors = {};
    if (_portals.isEmpty) return;
    
    // Group portals into pairs
    final processed = <int>{};
    int colorId = 0;
    
    for (final entry in _portals.entries) {
      final portal1 = entry.key;
      final portal2 = entry.value;
      
      // If this pair hasn't been processed yet
      if (!processed.contains(portal1) && !processed.contains(portal2)) {
        _portalColors[portal1] = colorId;
        _portalColors[portal2] = colorId;
        processed.add(portal1);
        processed.add(portal2);
        colorId++;
      }
    }
  }

  int calculateScore() {
    int baseScore = _enclosedCells.length;
    int cherryBonus = 0;
    
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (getCellType(row, col) == CellType.cherry) {
          final index = getCellIndex(row, col);
          if (_enclosedCells.contains(index)) {
            cherryBonus += 3;
          }
        }
      }
    }
    
    return baseScore + cherryBonus;
  }

  String _getScoreBreakdown() {
    if (_score == null || _enclosedCells.isEmpty) return '';
    
    int baseScore = _enclosedCells.length;
    int cherryCount = 0;
    
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (getCellType(row, col) == CellType.cherry) {
          final index = getCellIndex(row, col);
          if (_enclosedCells.contains(index)) cherryCount++;
        }
      }
    }
    
    if (cherryCount > 0) {
      return 'Base: $baseScore + Cherry bonus: $cherryCount × 3 = ${cherryCount * 3}';
    }
    return 'Base: $baseScore (no cherries enclosed)';
  }

  bool isOnEscapePath(int index) {
    return _escapePath.contains(index);
  }
  
  int getEscapePathIndex(int index) {
    return _escapePath.indexOf(index);
  }
  
  String _buildPuzzleTitle() {
    if (_puzzleData == null) return '';
    
    final day = _puzzleData!.day;
    final name = _puzzleData!.puzzleName;
    
    if (day != null && name != null) {
      // Format: "Day 20 - Trilemma II"
      return '$day - $name';
    } else if (day != null) {
      return day;
    } else if (name != null) {
      return name;
    }
    return '';
  }

  Widget buildCell(int row, int col) {
    // Debug: Log first few cells to verify puzzle data is being used
    if (row < 2 && col < 2 && row == 0 && col == 0) {
      print('DEBUG: buildCell(0,0) - _puzzleData is ${_puzzleData != null ? "NOT null" : "null"}, gridSize: $gridSize');
    }
    final cellType = getCellType(row, col);
    final isWall = hasWall(row, col);
    final enclosed = isEnclosed(row, col);
    final index = getCellIndex(row, col);
    final isHorse = cellType == CellType.horse;
    // Show escape path ONLY if hovering horse AND this cell is on the actual path
    final onEscapePath = _isHoveringHorse && isOnEscapePath(index);
    final pathIndex = onEscapePath ? getEscapePathIndex(index) : -1;
    
    // Check if this portal is being hovered or connected to a hovered portal
    final isPortal = cellType == CellType.portal;
    final isHoveringThisPortal = _hoveringPortalIndex == index;
    final connectedPortalIndex = _portals[index];
    final isConnectedPortalHovered = _hoveringPortalIndex != null && connectedPortalIndex == _hoveringPortalIndex;
    final showPortalConnection = isPortal && (isHoveringThisPortal || isConnectedPortalHovered);

    Widget cellContent = GestureDetector(
      behavior: HitTestBehavior.opaque, // Ensure taps are detected
      onTap: () {
        if (isHorse) {
          // Toggle horse hover state on tap
          final newHoverState = !_isHoveringHorse;
          setState(() {
            _isHoveringHorse = newHoverState;
            _hoveringPortalIndex = null; // Clear portal hover when interacting with horse
          });
          if (newHoverState) {
            onHorseHover(true);
          } else {
            onHorseHover(false);
          }
        } else if (isPortal) {
          // Toggle portal hover state on tap - show/hide connection line
          setState(() {
            if (_hoveringPortalIndex == index) {
              // Already tapped - untap it to hide the line
              _hoveringPortalIndex = null;
              print('Portal $index: Hiding line (was hovered)');
            } else {
              // Tap this portal to show connection line
              _hoveringPortalIndex = index;
              final connected = _portals[index];
              print('Portal $index: Showing line (connected to $connected)');
              // Clear horse hover when interacting with portal
              if (_isHoveringHorse) {
                _isHoveringHorse = false;
                _escapePath = [];
                _currentHorsePun = null;
              }
            }
          });
        } else {
          // Tapping grass or other cells - clear portal and horse hover, then toggle wall
          setState(() {
            _hoveringPortalIndex = null;
            if (_isHoveringHorse) {
              _isHoveringHorse = false;
              _escapePath = [];
              _currentHorsePun = null;
            }
          });
          toggleWall(row, col);
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _waterAnimationController,
          _pulseAnimationController,
          _pathAnimationController,
        ]),
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.all(1), // Minimal margin for tile effect
            decoration: BoxDecoration(
              color: _getCellBackgroundColor(
                cellType, 
                enclosed, 
                onEscapePath,
                showPortalConnection: showPortalConnection,
                portalColorId: isPortal ? _portalColors[index] : null,
              ),
              border: Border.all(
                  color: onEscapePath 
                    ? const Color(0xFFE74C3C).withValues(
                        alpha: 0.9 * (0.5 + 0.5 * _pathAnimationController.value),
                      )
                    : const Color(0xFF5BA318).withValues(alpha: 0.6), // Dark green tile border
                width: onEscapePath ? 3 : 2,
              ),
              boxShadow: onEscapePath
                  ? [
                      BoxShadow(
                      color: const Color(0xFFE74C3C).withValues(
                          alpha: 0.5 * _pathAnimationController.value,
                        ),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: ClipRect(
              clipBehavior: Clip.none, // Don't clip content - allow icons to be fully visible
              child: Stack(
                children: [
                  // Escape path highlight
                  if (onEscapePath)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C).withValues(
                            alpha: 0.3 * (0.7 + 0.3 * math.sin(_pathAnimationController.value * 2 * math.pi)),
                          ),
                        ),
                      ),
                    ),
                  
                  // Water animation
                  if (cellType == CellType.water)
                    CustomPaint(
                      painter: WaterPainter(_waterAnimationController),
                      size: Size.infinite,
                    ),
                  
                  // Cell content - ensure it's always visible
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                    child: Transform.scale(
                      scale: 1.0 + 0.1 * _pulseAnimationController.value * (onEscapePath ? 1 : 0),
                        child: _buildCellContent(cellType, enclosed, onEscapePath, index, cellSize: _currentCellSize),
                      ),
                    ),
                  ),
                  
                  // Animated wall
                  if (isWall)
                    AnimatedBuilder(
                      animation: _wallAnimationControllers[index] ?? 
                          AnimationController(vsync: this, value: 1.0),
                      builder: (context, child) {
                        final scale = _wallAnimationControllers[index]?.value ?? 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C3E50),
                              border: Border.all(
                                color: const Color(0xFF1A1A1A),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  
                  // Escape path arrow indicator
                  if (onEscapePath && pathIndex >= 0 && pathIndex < _escapePath.length - 1)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Opacity(
                        opacity: 0.7 + 0.3 * math.sin(_pathAnimationController.value * 2 * math.pi),
                        child: const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Color(0xFFE74C3C),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
    
    // Also support hover on desktop
    Widget finalCell = cellContent;
    if (isHorse) {
      finalCell = MouseRegion(
        onEnter: (_) => onHorseHover(true),
        onExit: (_) => onHorseHover(false),
        child: finalCell,
      );
    }
    
    if (isPortal) {
      finalCell = MouseRegion(
        onEnter: (_) => onPortalHover(index),
        onExit: (_) => onPortalHover(null),
        child: finalCell,
      );
    }
    
    return finalCell;
  }

  Color _getCellBackgroundColor(CellType cellType, bool enclosed, bool onEscapePath, {bool showPortalConnection = false, int? portalColorId}) {
    if (cellType == CellType.water) return _getWaterColor();
    if (cellType == CellType.portal) {
      if (showPortalConnection) {
        // Highlight connected portals with their pair color
        if (portalColorId != null) {
          final colors = [
            const Color(0xFF87CEEB), // Light blue
            const Color(0xFF9B59B6), // Purple
            const Color(0xFFE67E22), // Orange
            const Color(0xFF1ABC9C), // Teal
            const Color(0xFFE74C3C), // Red
            const Color(0xFFF39C12), // Yellow
            const Color(0xFF3498DB), // Blue
            const Color(0xFF16A085), // Green
          ];
          return colors[portalColorId % colors.length].withValues(alpha: 0.6);
        }
        return const Color(0xFF87CEEB).withValues(alpha: 0.5);
      }
      // Color-coded background for portals based on their pair
      if (portalColorId != null) {
        final colors = [
          const Color(0xFF87CEEB), // Light blue
          const Color(0xFF9B59B6), // Purple
          const Color(0xFFE67E22), // Orange
          const Color(0xFF1ABC9C), // Teal
          const Color(0xFFE74C3C), // Red
          const Color(0xFFF39C12), // Yellow
          const Color(0xFF3498DB), // Blue
          const Color(0xFF16A085), // Green
        ];
        return colors[portalColorId % colors.length].withValues(alpha: 0.3);
      }
      return const Color(0xFF87CEEB).withValues(alpha: 0.2); // Default light blue
    }
    if (onEscapePath) {
      return const Color(0xFFFF6B6B).withValues(alpha: 0.4); // Light red for escape path
    }
    if (enclosed && cellType != CellType.water && cellType != CellType.portal) {
      return _getGrassColor(true);
    }
    switch (cellType) {
      case CellType.grass:
        return _getGrassColor(false);
      case CellType.cherry:
        return _getGrassColor(false);
      case CellType.horse:
        return _getGrassColor(false);
      default:
        return _getGrassColor(false);
    }
  }

  Widget _buildCellContent(CellType cellType, bool enclosed, bool onEscapePath, int pathIndex, {double? cellSize}) {
    // Get the index for portals - need to pass it from buildCell
    final portalIndex = cellType == CellType.portal ? pathIndex : -1;
    
    // Calculate icon size based on cell size (default to 75% of cell if available, otherwise fixed size)
    // Use cellSize if provided, otherwise use a default that scales with grid size
    final effectiveCellSize = cellSize ?? _currentCellSize;
    final iconSizeFactor = effectiveCellSize * 0.75; // Use 75% of cell size for icons
    
    switch (cellType) {
      case CellType.horse:
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + 0.2 * _pulseAnimationController.value * (_isHoveringHorse ? 2.0 : 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFD700).withValues(alpha: _isHoveringHorse ? 0.7 : 0.5),
                      border: Border.all(
                        color: Colors.white,
                        width: _isHoveringHorse ? 4 : 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: _isHoveringHorse ? 1.0 : 0.6),
                          blurRadius: _isHoveringHorse ? 16 : 10,
                          spreadRadius: _isHoveringHorse ? 3 : 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Shadow layer
                        Icon(
                          Icons.pets,
                          size: iconSizeFactor + (_isHoveringHorse ? iconSizeFactor * 0.3 : 0),
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        // Main icon
                        Transform.translate(
                          offset: const Offset(-2, -2),
                          child: Icon(
                            Icons.pets, // Use icon instead of emoji for better visibility
                            size: iconSizeFactor + (_isHoveringHorse ? iconSizeFactor * 0.3 : 0), // Scale with cell size
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_isHoveringHorse)
              Positioned(
                bottom: -30,
                left: -40,
                right: -40,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    _currentHorsePun ?? 'Neigh!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      case CellType.cherry:
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + 0.15 * _pulseAnimationController.value,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Shadow layer
                        Icon(
                          Icons.circle,
                          size: iconSizeFactor * 0.85,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        // Main icon
                        Transform.translate(
                          offset: const Offset(-2, -2),
                          child: Icon(
                            Icons.circle, // Use filled circle icon for cherry
                            size: iconSizeFactor * 0.85, // Scale with cell size
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (enclosed)
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _pulseAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + 0.2 * _pulseAnimationController.value,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF4D03F),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      case CellType.water:
        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          child: Text(
            '💧',
            style: TextStyle(
              fontSize: iconSizeFactor * 0.7, // Scale with cell size
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 3,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        );
      case CellType.portal:
        // Calculate teleporter size based on cell size (defined outside AnimatedBuilder for closure access)
        final teleporterSize = effectiveCellSize * 0.95; // Slightly smaller than full cell
        
        return AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimationController, _pathAnimationController]),
          builder: (context, child) {
            final isHovered = _hoveringPortalIndex == portalIndex;
            // Get color for this portal pair
            final portalColorId = portalIndex >= 0 ? (_portalColors[portalIndex] ?? 0) : 0;
            final colors = [
              const Color(0xFF87CEEB), // Light blue - Pair 1
              const Color(0xFF9B59B6), // Purple - Pair 2
              const Color(0xFFE67E22), // Orange - Pair 3
              const Color(0xFF1ABC9C), // Teal - Pair 4
              const Color(0xFFE74C3C), // Red - Pair 5
              const Color(0xFFF39C12), // Yellow - Pair 6
              const Color(0xFF3498DB), // Blue - Pair 7
              const Color(0xFF16A085), // Green - Pair 8
            ];
            final portalColor = colors[portalColorId % colors.length];
            
            return Transform.scale(
              scale: 1.0 + 0.25 * _pulseAnimationController.value * (isHovered ? 1.5 : 1.0),
              child: Container(
                width: teleporterSize,
                height: teleporterSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHovered ? Colors.white : portalColor,
                    width: isHovered ? 6 : 5, // Thicker border for visibility
                  ),
                  gradient: RadialGradient(
                    colors: [
                      portalColor.withValues(alpha: isHovered ? 1.0 : 1.0), // More opaque
                      portalColor.withValues(alpha: isHovered ? 0.5 : 0.4),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: portalColor.withValues(alpha: isHovered ? 1.0 : 0.8),
                      blurRadius: isHovered ? 24 : 16,
                      spreadRadius: isHovered ? 4 : 3,
                    ),
                    // Additional black shadow for contrast
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.sync_alt,
                  color: Colors.white,
                  size: teleporterSize * 0.5, // Icon is half the container size
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 3,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated grass background with diagonal lines
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF5BA318), // Darker green base
            ),
            child: CustomPaint(
              painter: GrassBackgroundPainter(_pulseAnimationController),
              child: SafeArea(
                child: Column(
                  children: [
                    // Simple top bar matching the image design - minimal height
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Stack(
                  children: [
                    // Centered title and puzzle info
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'enclose.horse',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              letterSpacing: 2,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                          if (_puzzleData != null && (_puzzleData!.day != null || _puzzleData!.puzzleName != null))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _buildPuzzleTitle(),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w300,
                                  fontStyle: FontStyle.italic,
                                  color: const Color(0xFFFFD700), // Golden color
                                  letterSpacing: 1.5,
                                  height: 1.3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 3,
                                      offset: const Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Help button and hamburger menu in top-right
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Help button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _showTutorial = true;
                                  _tutorialAnimationController.forward();
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: const Icon(
                                  Icons.help_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Hamburger menu
                          PopupMenuButton<Map<String, dynamic>>(
                            icon: const Icon(
                              Icons.menu,
                              color: Colors.white,
                              size: 28,
                            ),
                            itemBuilder: (context) {
                              return [
                                PopupMenuItem(
                                  child: const Text('Reset'),
                                  onTap: () {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      resetWalls();
                                    });
                                  },
                                ),
                                if (_allPuzzles.isNotEmpty) ...[
                                  const PopupMenuDivider(),
                                  ..._allPuzzles.map((puzzle) {
                                    final dayNumber = puzzle['dayNumber'] as int? ?? 0;
                                    final name = puzzle['name'] as String? ?? '';
                                    return PopupMenuItem<Map<String, dynamic>>(
                                      value: puzzle,
                                      child: Text('Day $dayNumber: $name'),
                                    );
                                  }).toList(),
                                ],
                              ];
                            },
                            onSelected: (puzzle) {
                              _loadPuzzle(puzzleMetadata: puzzle);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Game grid
              Expanded(
                child: _isLoadingPuzzle
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF3498DB),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading today\'s puzzle...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // Use maximum available space for grid - use almost all available space
                          final availableHeight = constraints.maxHeight;
                          final availableWidth = constraints.maxWidth;
                          
                          // Calculate optimal cell size - use maximum space available
                          // Use both width and height, take the minimum to ensure it fits
                          // Use almost all available space (98% to account for minimal padding)
                          final cellSizeFromWidth = availableWidth / gridSize;
                          final cellSizeFromHeight = availableHeight * 0.98 / gridSize; // Use 98% of height
                          final cellSize = math.min(cellSizeFromWidth, cellSizeFromHeight);
                          
                          // Store cell size for icon scaling
                          if (_currentCellSize != cellSize) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                _currentCellSize = cellSize;
                              });
                            });
                          }
                          
                          // Calculate actual grid dimensions
                          final gridWidth = cellSize * gridSize;
                          final gridHeight = cellSize * gridSize;
                          
                          final gridContent = Container(
                            width: gridWidth,
                            height: gridHeight,
                            margin: const EdgeInsets.all(2), // Minimal margin to maximize grid size
                            decoration: BoxDecoration(
                              color: const Color(0xFF7ED321), // Green background for grid area
                              border: Border.all(
                                color: const Color(0xFF5BA318).withValues(alpha: 0.8),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                                  child: Stack(
                                    children: [
                                      // Grid cells
                                      GridView.builder(
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: gridSize,
                                    crossAxisSpacing: 0, // No spacing for connected tiles
                                    mainAxisSpacing: 0, // No spacing for connected tiles
                                        ),
                                        itemCount: gridSize * gridSize,
                                        itemBuilder: (context, index) {
                                          final row = index ~/ gridSize;
                                          final col = index % gridSize;
                                          return buildCell(row, col);
                                        },
                                      ),
                                      // Portal connection lines overlay (only show on hover)
                                      // Always paint (even when null) so repaints work correctly
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: PortalConnectionPainter(
                                              portals: _portals,
                                              portalColors: _portalColors,
                                              hoveringPortalIndex: _hoveringPortalIndex,
                                              gridSize: gridSize,
                                              cellMargin: 1.0, // Actual margin used in cells
                                              crossAxisSpacing: 0.0, // No spacing for tiles
                                              mainAxisSpacing: 0.0, // No spacing for tiles
                                              containerPadding: 0.0, // No padding needed
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                          
                          // Fill entire available space - position more towards top
                          return SizedBox.expand(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8), // Small padding from top
                                child: gridContent,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Tutorial Overlay
          if (_showTutorial)
            AnimatedBuilder(
              animation: _tutorialAnimationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _tutorialAnimationController.value,
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * _tutorialAnimationController.value,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.7),
                      child: Center(
                        child: _buildTutorialOverlay(),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Bottom stats and buttons bar (matching image design)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                                children: [
                  // Stats row (Walls left, Score right)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                        // Walls (bottom left)
                                              Text(
                          'Walls: $remainingWalls/$maxWalls',
                                                style: const TextStyle(
                            fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        // Score (bottom right)
                                                Text(
                          'Score: ${_score?.toString() ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                            letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                  // Buttons row (Reset and Submit centered)
                                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                        // Reset button (white background, black text)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: resetWalls,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Reset',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Submit button (light green background, black text)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _hasSubmitted ? null : checkEnclosure,
                            borderRadius: BorderRadius.circular(6),
                              child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                decoration: BoxDecoration(
                                color: _hasSubmitted 
                                    ? Colors.grey[400] 
                                    : const Color(0xFF8ED632), // Light green
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                                ),
                                child: Text(
                                _hasSubmitted ? 'Submitted' : 'Submit',
                                style: TextStyle(
                                  fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  color: _hasSubmitted ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                        ),
                        // Retry button (only shown after submission)
                        if (_horseEnclosed != null) ...[
                          const SizedBox(width: 12),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: retryGame,
                              borderRadius: BorderRadius.circular(6),
                                child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                          color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'Retry',
                                                style: TextStyle(
                                    fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                                          ),
                                        ),
                                      ],
                                    ],
                              ),
                            ),
                        ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTutorialOverlay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C3E50),
            Color(0xFF34495E),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(
          color: const Color(0xFF3498DB).withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Text(
            'How to Play',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3498DB),
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: Color(0xFF3498DB),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Tab selector
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    'How to Play',
                    0,
                    Icons.info_outline,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    'Puzzle Info',
                    1,
                    Icons.extension,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Tab content
          SizedBox(
            height: 400,
            child: IndexedStack(
              index: _tutorialTabIndex,
              children: [
                _buildHowToPlayTab(),
                _buildPuzzleInfoTab(),
              ],
            ),
          ),
          
          // Start button (always visible)
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF27AE60), Color(0xFF229954)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF27AE60).withValues(alpha: 0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: closeTutorial,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Start Playing',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _tutorialTabIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _tutorialTabIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF3498DB).withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: const Color(0xFF3498DB),
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF3498DB) : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF3498DB) : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHowToPlayTab() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Objective
          const Text(
            'Enclose the horse in the biggest possible pen!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          
          // The Rules header
          const Row(
            children: [
              Expanded(
                child: Divider(
                  color: Color(0xFF3498DB),
                  thickness: 2,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'The Rules',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3498DB),
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Color(0xFF3498DB),
                  thickness: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Rules list
          _buildRuleItem('Click grass tiles to place walls.'),
          _buildRuleItem('You have limited walls.'),
          _buildRuleItem('The horse can move in 4 directions. Tap it to see escape path!', icon: Icons.pets, iconColor: Colors.white),
          _buildRuleItem('Enclosed cherries give +3 points!', icon: Icons.circle, iconColor: Colors.red.shade700),
          _buildRuleItem('Portals connect distant cells - tap to see connections!', icon: Icons.sync_alt, iconColor: const Color(0xFF87CEEB)),
          _buildRuleItem('Bigger enclosure = bigger score, but you only have one chance to submit!'),
          const SizedBox(height: 24),
          
          // Tip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF4D03F).withValues(alpha: 0.3),
                  const Color(0xFFF39C12).withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF4D03F),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb,
                  color: Color(0xFFF4D03F),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: $_currentTip',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF4D03F),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPuzzleInfoTab() {
    final puzzle = _puzzleData;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Puzzle Info Title
          const Text(
            'Puzzle Information',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3498DB),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          
          if (puzzle != null) ...[
            // Puzzle Name
            if (puzzle.puzzleName != null)
              _buildInfoCard(
                'Puzzle Name',
                puzzle.puzzleName!,
                Icons.extension,
                const Color(0xFF3498DB),
              ),
            
            const SizedBox(height: 12),
            
            // Made By (Creator)
            if (puzzle.creatorName != null)
              _buildInfoCard(
                'Made By',
                puzzle.creatorName!,
                Icons.person,
                const Color(0xFFE67E22),
              ),
            
            const SizedBox(height: 12),
            
            // Day
            if (puzzle.day != null)
              _buildInfoCard(
                'Day',
                puzzle.day!,
                Icons.calendar_today,
                const Color(0xFFE74C3C),
              ),
            
            const SizedBox(height: 12),
            
            // Level ID
            if (puzzle.levelId != null)
              _buildInfoCard(
                'Level ID',
                puzzle.levelId!,
                Icons.tag,
                const Color(0xFF9B59B6),
              ),
            
            const SizedBox(height: 12),
            
            // Date
            if (puzzle.date != null)
              _buildInfoCard(
                'Date',
                _formatDate(puzzle.date!),
                Icons.event,
                const Color(0xFF3498DB),
              ),
            
            const SizedBox(height: 12),
            
            // Grid Size
            _buildInfoCard(
              'Grid Size',
              '${puzzle.gridSize} × ${puzzle.gridSize}',
              Icons.grid_on,
              const Color(0xFF27AE60),
            ),
            
            const SizedBox(height: 12),
            
            // Max Walls
            _buildInfoCard(
              'Max Walls',
              '${puzzle.maxWalls}',
              Icons.border_style,
              const Color(0xFFF39C12),
            ),
            
            const SizedBox(height: 12),
            
            // Horse Position
            _buildInfoCard(
              'Horse Position',
              'Row ${puzzle.horseRow + 1}, Col ${puzzle.horseCol + 1}',
              Icons.location_on,
              const Color(0xFF8B4513),
            ),
            
            const SizedBox(height: 12),
            
            // Portals
            _buildInfoCard(
              'Portals',
              puzzle.portals.isEmpty ? 'None' : '${puzzle.portals.length ~/ 2} pairs',
              Icons.sync_alt,
              const Color(0xFF9B59B6),
            ),
            
            const SizedBox(height: 12),
            
            // Source
            if (puzzle.puzzleUrl != null)
              _buildInfoCard(
                'Source',
                'enclose.horse',
                Icons.link,
                const Color(0xFF95A5A6),
              ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Loading puzzle information...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  Widget _buildRuleItem(String text, {IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF3498DB),
              shape: BoxShape.circle,
            ),
          ),
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.white).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: iconColor ?? Colors.white,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                height: 1.5,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
