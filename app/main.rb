$gtk.reset

def render_cube_in_grid(grid, x, y, color)
  $args.outputs.solids << [grid.x_pos + (x * 32), grid.y_pos + (y * 32), 32, 32, *color]
  $args.outputs.borders << [grid.x_pos + (x * 32), grid.y_pos + (y * 32), 32, 32, 0, 0, 0]
end

class Piece
  DELAY = 0.1.seconds

  attr_reader :x, :y, :color

  def initialize(grid, x, y, color)
    @grid = grid
    @x = x
    @y = y
    @color = color
    @next_move = DELAY
  end

  def render
    render_cube_in_grid(@grid, @x, @y, @color)
  end

  def current_piece_colliding?
    return @y == 0 || @grid.filled?(@x, @y-1)
  end

  def inside_grid_bounds?(x, y)
    x >= 0 && x <= @grid.cols - 1
  end

  def overlapping?(x, y)
    @grid.filled?(x, y)
  end

  def valid_position?(x, y)
    inside_grid_bounds?(x, y) && !overlapping?(x, y)
  end

  def move_left
    @x -= 1 if valid_position?(@x - 1, @y)
  end

  def move_right
    @x += 1 if valid_position?(@x + 1, @y)
  end

  def update
    @next_move -= 1

    if @next_move <= 0
      $args.state.game.plant_current_piece if current_piece_colliding?
      @y -= 1 if valid_position?(@x, @y - 1)
      @next_move = DELAY
    end
    
    unless current_piece_colliding?
      keys = $args.inputs.keyboard
      if (keys.key_down.down || keys.key_held.down) && @y > 0
        @next_move -= 10
      end
      if keys.key_down.left
        move_left
      end
      if keys.key_down.right && @x < @grid.cols - 1
        move_right
      end
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

  def place(piece)
    @tiles[piece.y][piece.x] = piece.color
  end

  # check if any row in the grid is full.
  # if it is, delete the row and shift all rows above it down by 1
  def update
    @tiles.each_with_index do |row, row_index|
      if row.all? { |cell| !cell.nil? }
        @tiles = @tiles[0...row_index] + @tiles[row_index+1..-1]
        @tiles << Array.new(@cols, nil)
      end
    end
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

class TetrisGame
  def initialize
    @score = 0
    @grid = Grid.new(10, 20)
    start_new_piece
  end

  def render_background
    $args.outputs.solids << [0, 0, 1280, 720, 0, 0, 0]
  end

  def render
    render_background
    @grid.render
    @current_piece.render
  end

  def update
    @current_piece.update
  end

  def start_new_piece
    @current_piece = Piece.new(@grid, 4, 19, [255, 0, 0])
  end

  def plant_current_piece
    @grid.place(@current_piece)
    
    if @current_piece.y >= 19
      $game_over = true
    else
      @grid.update
      start_new_piece
    end
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
end
