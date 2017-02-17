import mach.sdl;
import mach.math;
import mach.text;
import mach.range;

import symbol;



/// Represents game board state.
struct Board{
    struct Cell{
        enum Cell Empty = Cell(false, false, false, 0);
        enum Cell Mine = Cell(true, false, false, 0);
        bool mined;
        bool revealed;
        bool flagged;
        uint neighbors = 0;
        auto tojson() const{
            auto value = Json.Value(Json.Value.Type.Object);
            value["mined"] = cast(int) this.mined;
            value["revealed"] = cast(int) this.revealed;
            value["flagged"] = cast(int) this.flagged;
            return value;
        }
    }
    
    uint width;
    uint height;
    Cell[] cells;
    uint mines = 0;
    uint revealed = 0;
    bool revealedmine = false;
    Texture* background = null;
    
    this(in uint width, in uint height){
        this.width = width;
        this.height = height;
        this.cells = new Cell[width * height];
    }
    
    auto tojson() const{
        auto value = Json.Value(Json.Value.Type.Object);
        value["cells"] = Json.serialize(this.cells);
        return value;
    }
    static typeof(this) fromjson(in Json.Value value){
        Board board;
        board.cells = Json.deserialize!(Cell[])(value["cells"]);
        board.width = cast(uint) sqrt(board.cells.length);
        board.height = board.width;
        board.populateneighbors();
        for(int i = 0; i < board.width; i++){
            for(int j = 0; j < board.height; j++){
                board.mines += board[i, j].mined;
                board.revealed += board[i, j].revealed && !board[i, j].mined;
                if(board[i, j].revealed && board[i, j].mined) board.revealedmine = true;
            }
        }
        return board;
    }
    
    /// Reveal a cell and, if it has no neighboring cells, reveal a region
    /// in a flood fill.
    void reveal(in uint x, in uint y){
        if(!this[x, y].revealed){
            if(this[x, y].mined){
                this[x, y].revealed = true;
                this.revealedmine = true;
            }else{
                bool[] visited = new bool[this.cells.length];
                Vector2!int[] pending;
                pending ~= Vector2!int(x, y);
                while(pending.length > 0){
                    auto vec = pending[$-1];
                    pending.length -= 1;
                    visited[this.cellindex(vec.x, vec.y)] = true;
                    this.revealed += !this[vec].revealed;
                    this[vec].revealed = true;
                    if(this[vec].neighbors == 0){
                        void neighbor(in int x, in int y){
                            immutable vmod = Vector2!int(vec.x + x, vec.y + y);
                            if(this.inbounds(vmod.x, vmod.y) && !visited[this.cellindex(vmod.x, vmod.y)]){
                                pending ~= vmod;
                            }
                        }
                        neighbor(-1, -1);
                        neighbor(-1, +0);
                        neighbor(-1, +1);
                        neighbor(+0, -1);
                        neighbor(+0, +1);
                        neighbor(+1, -1);
                        neighbor(+1, +0);
                        neighbor(+1, +1);
                    }
                }
            }
        }
    }
    
    auto countrevealed(){
        uint sum = 0;
        foreach(const cell; this.cells) sum += cell.revealed && !cell.mined;
        return sum;
    }
    
    /// Draw unrevealed cells and revealed mines
    void renderunrevealed(in Box!int target, in ulong tick, in bool duds){
        static const cellcolors = [0.5, 0.55, 0.525, 0.575];
        RenderContext context;
        for(int i = 0; i < this.width; i++){
            for(int j = 0; j < this.height; j++){
                immutable cell = this.getrendercell(target.size, i, j) + target.topleft;
                if(!this[i, j].revealed){
                    context.color = Color!float.gray(cellcolors[
                        (i + (j % cellcolors.length)) % cellcolors.length
                    ]);
                    context.rect(cell);
                }else if(this[i, j].mined){
                    if(duds){
                        context.color = Color!float.gray(0.25);
                    }else{
                        context.color = (tick % 200 < 100 ?
                            Color!float(0.98, 0.38, 0.1) :
                            Color!float(1.0, 0.65, 0.3)
                        );
                    }
                    context.circle(cell.center, cell.width * 0.33);
                }
            }
        }
    }
    
    /// Draw flags on unrevealed cells
    void renderflags(in Box!int target){
        RenderContext context;
        context.color = Color!float(0.0, 0.0, 0.05);
        for(int i = 0; i < this.width; i++){
            for(int j = 0; j < this.height; j++){
                if(!this[i, j].revealed && this[i, j].flagged){
                    immutable cell = this.getrendercell(target.size, i, j) + target.topleft;
                    immutable xmargin = cell.width / 6;
                    immutable ymargin = cell.height / 8;
                    immutable renderat = Box!int(cell.x + xmargin, cell.y + ymargin, cell.maxx - xmargin, cell.maxy - ymargin);
                    Symbol.Bang.render(context, renderat);
                }
            }
        }
    }
    
    /// Generate a new board given a number of mines and a render target size
    void populate(in uint minecount, in Vector2!int size){
        this.mines = minecount;
        this.revealedmine = false;
        this.revealed = 0;
        this.populatemines(minecount);
        this.populateneighbors();
        this.populatebackground(size);
    }
    /// Place a given number of mines on the board
    void populatemines(in uint minecount){
        this.fill(Cell.Empty);
        auto rng = xorshift();
        for(uint i = 0; i < minecount; i++){
            uint index = rng.random!uint(uint(0), cast(uint)(this.cells.length - 1));
            while(this.cells[index].mined) index = (index + 1) % this.cells.length;
            this.cells[index] = Cell.Mine;
        }
    }
    /// Calculate the number of neighboring mines for each cell
    void populateneighbors(){
        for(int i = 0; i < this.width; i++){
            for(int j = 0; j < this.height; j++){
                this[i, j].neighbors = this.cellneighbors(i, j);
            }
        }
    }
    
    /// Helper to get a box representing a cell on a surface representing the
    /// board's static background.
    auto getrendercell(T)(in Vector2!T size, in uint x, in uint y) const{
        return Box!double(
            size.x * x / this.width,
            size.y * y / this.height,
            size.x * (x + 1) / this.width - 1,
            size.y * (y + 1) / this.height - 1
        );
    }
    /// Draw the board's static background, which displays neighbor counts.
    void populatebackground(in Vector2!int size){
        if(this.background !is null) this.background.free();
        auto surface = Surface(size.x, size.y);
        surface.fill(Color!float(0.45, 0.45, 0.45, 1.0));
        for(int i = 0; i < this.width; i++){
            for(int j = 0; j < this.height; j++){
                if(!this[i, j].mined && this[i, j].neighbors > 0){
                    this.drawbgnumber(&surface, size, i, j, this[i, j].neighbors);
                }else if(!this[i, j].mined){
                    this.drawbgdot(&surface, size, i, j);
                }
            }
        }
        this.background = new Texture(surface);
    }
    /// Draw a number representing the number of neighboring mines onto the
    /// board's static background.
    void drawbgnumber(Surface* surface, in Vector2!int size, in uint x, in uint y, in uint number) const{
        static const colors = [
            Color!float(0.5, 0.5, 0.5), // 0
            Color!float(0.25, 0.4, 0.7), // 1
            Color!float(0.3, 0.46, 0.05), // 2
            Color!float(0.65, 0.35, 0.05), // 3
            Color!float(0.6, 0.1, 0.05), // 4
            Color!float(0.55, 0.0, 0.25), // 5
            Color!float(0.4, 0.05, 0.45), // 6
            Color!float(0.2, 0.1, 0.55), // 7
            Color!float(0.05, 0.0, 0.3), // 8
        ];
        with(Symbol){
            static const symbols = [
                Zero, One, Two, Three, Four, Five, Six, Seven, Eight
            ];
            immutable cell = this.getrendercell(size, x, y);
            immutable xmargin = cell.width / 6;
            immutable ymargin = cell.height / 8;
            immutable renderat = Box!int(cell.x + xmargin, cell.y + ymargin, cell.maxx - xmargin, cell.maxy - ymargin);
            symbols[number].render(surface, colors[number], renderat + Vector2!int(0, 2));
            symbols[number].render(surface, Color!float(0.95, 0.95, 0.95), renderat);
        }
    }
    /// Draw a dot representing a cell with no neighboring mines onto the
    /// board's static background.
    void drawbgdot(Surface* surface, in Vector2!int size, in uint x, in uint y) const{
        immutable cell = this.getrendercell(size, x, y);
        surface.fill(
            Box!int(cell.size / 4).centered(cell.center),
            Color!float(0.55, 0.55, 0.55)
        );
    }
    
    /// Get the number of neighboring mines given a cell.
    uint cellneighbors(in uint x, in uint y){
        uint count = 0;
        for(int nx = -1; nx <= 1; nx++){
            for(int ny = -1; ny <= 1; ny++){
                if(nx != 0 || ny != 0){
                    immutable i = cast(uint)(x + nx);
                    immutable j = cast(uint)(y + ny);
                    if(this.inbounds(i, j)) count += this[i, j].mined;
                }
            }
        }
        return count;
    }
    
    /// Fill the board with a cell.
    void fill(in Cell cell){
        for(uint i = 0; i < this.width; i++){
            for(uint j = 0; j < this.height; j++){
                this[i, j] = cell;
            }
        }
    }
    
    /// Get the size of the board in cells as a vector.
    @property auto size() const{
        return Vector2!int(this.width, this.height);
    }
    
    /// Get whether a coordinate is within the board's bounds.
    bool inbounds(in uint x, in uint y) const{
        return x >= 0 && x < this.width && y >= 0 && y < this.width;
    }
    
    auto cellindex(in uint x, in uint y) const{
        return x + (y * this.width);
    }
    /// Get the cell at a position.
    auto ref opIndex(in uint x, in uint y){
        assert(this.inbounds(x, y));
        return this.cells[this.cellindex(x, y)];
    }
    auto ref opIndex(N)(in Vector2!N v){
        return this[cast(uint) v.x, cast(uint) v.y];
    }
}
