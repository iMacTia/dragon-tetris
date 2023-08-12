$gtk.reset

def render_cube_in_grid(grid, x, y, color)
  $args.outputs.solids << [grid.x_pos + (x * 32), grid.y_pos + (y * 32), 32, 32, *color]
  $args.outputs.borders << [grid.x_pos + (x * 32), grid.y_pos + (y * 32), 32, 32, *COLORS[:black]]
end

COLORS = {
  black: [0, 0, 0],
  white: [255, 255, 255],
  red: [255, 0, 0],
  green: [0, 255, 0],
  blue: [0, 0, 255],
  yellow: [255, 255, 0],
  orange: [255, 165, 0],
  purple: [128, 0, 128],
  cyan: [0, 255, 255]
}

class Piece
  DELAY = 0.4.seconds

  attr_reader :x, :y, :color, :shape

  def initialize(shape:, color:, grid: nil, x: 0, y: 0)
    @grid = grid
    @x = x
    @y = y
    @color = color
    @shape = shape
    @next_move = DELAY
  end

  def add_to(grid, start_x, start_y)
    @grid = grid
    @x = start_x
    @y = start_y
  end

  def each_cell(x = @x, y = @y, &block)
    shape.each_with_index do |row, col_index|
      row.each_with_index do |cell, row_index|
        yield(cell, x + row_index, y + col_index, row_index, col_index)
      end
    end
  end

  def each_filled_cell(x = @x, y = @y, &block)
    each_cell do |cell, row_index_in_grid, col_index_in_grid, row_index, col_index|
      yield(cell, x + row_index, y + col_index, row_index, col_index) if cell == 1
    end
  end

  def touching?
    each_filled_cell do |cell, row_index_in_grid, col_index_in_grid|
      return true if col_index_in_grid == 0 || @grid.filled?(row_index_in_grid, col_index_in_grid-1)
    end
    false
  end

  def inside_grid_bounds?(x, y)
    each_filled_cell(x, y) do |cell, row_index_in_grid, col_index_in_grid|
      return false if row_index_in_grid < 0 || row_index_in_grid >= @grid.cols
    end
    true
  end

  def overlapping?(x = @x, y = @y)
    each_filled_cell(x, y) do |cell, row_index_in_grid, col_index_in_grid|
      return true if @grid.filled?(row_index_in_grid, col_index_in_grid)
    end
    false
  end

  def valid_position?(x, y)
    inside_grid_bounds?(x, y) && !overlapping?(x, y)
  end

  def move_to(x, y)
    @x = x
    @y = y
  end

  def move_left
    @x -= 1 if valid_position?(@x - 1, @y)
  end

  def move_right
    @x += 1 if valid_position?(@x + 1, @y)
  end

  def rotate_left
    new_shape = Array.new(@shape[0].length) { Array.new(@shape.length, 0) }
    @shape.each_with_index do |row, row_index|
      row.each_with_index do |cell, col_index|
        new_shape[col_index][row.length - row_index - 1] = cell
      end
    end
    
    # test new shape
    old_shape = @shape
    @shape = new_shape
    @shape = old_shape unless valid_position?(@x, @y)
  end

  def process_inputs
    keys = $args.inputs.keyboard

    rotate_left if keys.key_down.z

    if (keys.key_down.down || keys.key_held.down)
      @next_move -= 10
    end
    if keys.key_down.left
      move_left
    end
    if keys.key_down.right && @x < @grid.cols - 1
      move_right
    end
  end

  def update
    process_inputs

    @next_move -= 1

    if @next_move <= 0
      $args.state.game.plant_current_piece if touching?
      @y -= 1 if valid_position?(@x, @y - 1)
      @next_move = DELAY
    end
  end

  def render
    each_cell do |cell, row_index_in_grid, col_index_in_grid, row_index, col_index|
      render_cube_in_grid(@grid, row_index_in_grid, col_index_in_grid, @color) if cell == 1
    end
  end
end

class Grid
  attr_reader :rows, :cols, :total_width, :total_height, :x_pos, :y_pos, :tiles

  def initialize(width, height)
    @rows = height
    @cols = width
    @total_width = (@cols * 32)
    @total_height = (@rows * 32)
    @x_pos = (1280 - @total_width) / 2
    @y_pos = (720 - @total_height) / 2
    @tiles = Array.new(@rows) { Array.new(@cols, nil) }
  end

  def filled?(x, y)
    !@tiles[y][x].nil?
  end

  def plant(piece)
    piece.each_filled_cell do |cell, row_index_in_grid, col_index_in_grid|
      @tiles[col_index_in_grid][row_index_in_grid] = piece.color
    end
  end

  def update
    @tiles.each_with_index do |row, row_index|
      if row.all? { |cell| !cell.nil? }
        @tiles[row_index] = nil
        @tiles << Array.new(@cols, nil)
      end
    end
    @tiles.compact!
  end

  def render
    $args.outputs.borders << [@x_pos - 2, @y_pos - 2, @total_width + 4, @total_height + 4, 255, 255, 255]
    @tiles.each_with_index do |row, col_index| # 0-19
      row.each_with_index do |cell, row_index| # 0-9
        render_cube_in_grid(self, row_index, col_index, @tiles[col_index][row_index]) if @tiles[col_index][row_index]
      end
    end
  end
end

class NextGrid
  attr_reader :x_pos, :y_pos

  def initialize
    @x_pos = 900
    @y_pos = 360
  end

  def render
    $args.outputs.labels << [963, 530, "Next piece", 5, 1, *COLORS[:white]]
    $args.outputs.borders << [x_pos - 2, y_pos - 2, 132, 132, 255, 255, 255]
  end
end

class TetrisGame
  attr_reader :grid, :next_grid, :current_piece, :next_piece, :score

  def initialize
    @score = 0
    @grid = Grid.new(10, 20)
    @next_grid = NextGrid.new
    start_new_piece
  end

  def render_background
    $args.outputs.solids << [0, 0, 1280, 720, 0, 0, 0]
  end

  def render
    render_background
    @grid.render
    @next_grid.render
    @current_piece.render
    @next_piece.render
  end

  def update
    @current_piece.update
  end

  def start_new_piece
    @current_piece = @next_piece || PIECES.sample.dup
    current_piece.add_to(grid, 4, 20 - current_piece.shape.length)
    $game_over = current_piece.overlapping?
    @next_piece = PIECES.sample.dup
    next_piece.add_to(next_grid, 0, 3 - @next_piece.shape.length)
  end

  def plant_current_piece
    @grid.plant(@current_piece)
    
    @grid.update
    start_new_piece
  end

  def tick
    if $game_over
      $args.outputs.labels << [640, 360, "Game Over", 5, 1]
    else
      update
      render
    end
  end
end

PIECES = [
  Piece.new(shape: [[0, 0, 0], [1, 1, 1], [0, 1, 0]], color: COLORS[:red]), # T
  Piece.new(shape: [[1, 1], [1, 1]], color: COLORS[:yellow]), # O
  Piece.new(shape: [[0, 0, 0], [0, 1, 1], [1, 1, 0]], color: COLORS[:green]), # S
  Piece.new(shape: [[0, 0, 0], [1, 1, 0], [0, 1, 1]], color: COLORS[:blue]), # Z
  Piece.new(shape: [[0, 0, 0, 0], [0, 0, 0, 0], [1, 1, 1, 1], [0, 0, 0, 0]], color: COLORS[:orange]), # I
  Piece.new(shape: [[0, 0, 0], [1, 1, 1], [0, 0, 1]], color: COLORS[:purple]), # J
  Piece.new(shape: [[0, 0, 0], [1, 1, 1], [1, 0, 0]], color: COLORS[:cyan]) # L
]

def tick(args)
  $args = args
  args.state.game ||= TetrisGame.new
  
  if $paused
    args.outputs.labels  << [640, 360, "Paused", 5, 1]
  else
    args.state.game.tick
  end
  
  if (args.inputs.keyboard.key_down.space)
    if $game_over
      $game_over = false
      $gtk.reset
    else
      $paused = !$paused 
    end
  end

  $gtk.reset if args.inputs.keyboard.key_down.r
end
