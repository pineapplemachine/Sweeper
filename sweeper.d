import mach.sdl;
import mach.math;
import mach.io;
import mach.text;

import board;



struct Settings{
    enum Size: int{
        Small = 0, Medium = 1, Big = 2
    }
    enum Difficulty: int{
        Easy = 0, Medium = 1, Hard = 2
    }
    uint resolution;
    Size boardsize;
    Difficulty difficulty;
}



class Sweeper: Application{
    enum settingspath = "settings.json";
    enum savepath = "savegame.json";
    enum State{Play, Win, Lose, Menu}
    
    static int[] presetresolutions = [256, 512, 1024, 2048];
    static int[] boardsizes = [12, 16, 20];
    static double[] difficulties = [0.10, 0.15, 0.22];
    
    static const uibackground = Color!float.gray(0.035, 0.64);
    
    int[] allowedresolutions;
    Box!int boardtarget;
    
    Board board;
    RenderContext context;
    State laststate = State.Play;
    State state = State.Win;
    bool gameover = false;
    Vector2!int mousecell;
    bool mouseinboard;
    Settings settings;
    bool optionsview = false;
    
    Texture* wingraphic;
    Texture* losegraphic;
    Texture* newgamegraphic;
    Texture* optionsgraphic;
    Texture* quitgraphic;
    Texture* resgraphic;
    Texture* sizegraphic;
    Texture* diffgraphic;
    Texture* okgraphic;
    Texture* cancelgraphic;
    
    /// Load settings file
    void loadsettings(){
        auto desktop = DisplayMode.desktop;
        foreach(res; presetresolutions){
            if(res <= desktop.width && res <= desktop.height){
                allowedresolutions ~= res;
            }
        }
        if(File.exists(settingspath)){
            bool success = true;
            try{
                settings = Json.parse!Settings(File.readstring(settingspath));
            }catch(Exception e){
                success = false;
            }
            if(!success) loaddefaultsettings;
        }else{
            loaddefaultsettings();
        }
    }
    /// Load default settings and save them to the settings file
    void loaddefaultsettings(){
        immutable defaultresolution = (allowedresolutions.length > 1 ?
            allowedresolutions[$-2] :
            allowedresolutions[$-1]
        );
        settings = Settings(
            defaultresolution,
            settings.Size.Medium,
            settings.Difficulty.Medium,
        );
        savesettings();
    }
    /// Save settings to file
    void savesettings(){
        File.writeto(settingspath, Json.pretty(settings));
    }
    
    /// Load game state from file
    /// Or start a new game when there is no such file
    void loadgame(){
        if(File.exists(savepath)){
            bool success = true;
            try{
                board = Json.parse!Board(File.readstring(savepath));
            }catch(Exception e){
                success = false;
                newgame();
            }
            if(success){
                board.populatebackground(boardtarget.size);
                if(board.revealedmine){
                    state = State.Lose;
                    gameover = true;
                }else if(board.revealed + board.mines == board.width * board.height){
                    state = State.Win;
                    gameover = true;
                }else{
                    state = State.Play;
                    gameover = false;
                }
                laststate = state;
            }
        }else{
            newgame();
        }
    }
    /// Save game state to file
    void savegame(){
        File.writeto(savepath, Json.encode(board));
    }
    /// Remove saved game state file
    void removesavegame(){
        if(File.exists(savepath)) File.remove(savepath);
    }
    
    /// Begin a new game with the current settings
    void newgame(){
        removesavegame();
        immutable size = boardsizes[settings.boardsize];
        immutable mines = cast(uint)(size * size * difficulties[settings.difficulty]);
        board = Board(size, size);
        board.populate(mines, boardtarget.size);
        gameover = false;
        state = State.Play;
        laststate = state;
    }
    
    /// Initialize the application
    override void initialize(){
        loadsettings();
        window = new Window("Sweeper", Vector2!int(settings.resolution));
        if(window.width > 400){
            boardtarget = Box!int(20, 20, window.size.x - 20, window.size.y - 20);
        }else{
            boardtarget = Box!int(window.size);
        }
        inittext();
        loadgame();
    }
    /// Load font and text graphics
    void inittext(int size = 128){
        auto font = Font("Tuffy_Bold.ttf", size);
        auto white = Color!float.gray(1.0);
        wingraphic = new Texture(font.rendertextblended(white, "YOU WIN"));
        losegraphic = new Texture(font.rendertextblended(white, "YOU LOSE"));
        newgamegraphic = new Texture(font.rendertextblended(white, "NEW GAME"));
        optionsgraphic = new Texture(font.rendertextblended(white, "OPTIONS"));
        quitgraphic = new Texture(font.rendertextblended(white, "QUIT"));
        resgraphic = new Texture(font.rendertextblended(white, "RESOLUTION"));
        sizegraphic = new Texture(font.rendertextblended(white, "BOARD SIZE"));
        diffgraphic = new Texture(font.rendertextblended(white, "DIFFICULTY"));
        okgraphic = new Texture(font.rendertextblended(white, "OK"));
        cancelgraphic = new Texture(font.rendertextblended(white, "CANCEL"));
        font.close();
    }
    
    /// Conclude the application
    override void conclude(){}
    
    /// Main loop
    override void main(){
        updatemouse();
        clear(0.55, 0.55, 0.55);
        board.background.draw(boardtarget);
        board.renderunrevealed(boardtarget, ticks, state is State.Win);
        if(state is State.Play) highlightmouse();
        board.renderflags(boardtarget);
        final switch(state){
            case State.Play: play(); break;
            case State.Win: win(); break;
            case State.Lose: lose(); break;
            case State.Menu: menu(); break;
        }
        if(keys.released(KeyCode.Escape)){
            if(state is State.Menu){
                state = laststate;
            }else{
                laststate = state;
                state = State.Menu;
                optionsview = false;
            }
        }
        swap();
    }
    
    /// Update cursor information according to mouse position
    void updatemouse(){
        mousecell = Vector2!int(
            (mouse.position - boardtarget.topleft) /
            (Vector2!double(boardtarget.size) / board.size)
        );
        mouseinboard = mousecell in Box!int(board.size) && (
            mouse.position.x >= boardtarget.x &&
            mouse.position.y >= boardtarget.y
        );
    }
    /// Highlight the cell under the mouse
    void highlightmouse(){
        if(mouseinboard){
            if(!board[mousecell].revealed){
                context.color = Color!float(1.0, 1.0, 1.0, 0.2);
                immutable rendercell = board.getrendercell(
                    boardtarget.size, mousecell.x, mousecell.y
                );
                context.rect(rendercell + boardtarget.topleft);
            }
        }
    }
    
    /// Handle normal gameplay state
    void play(){
        if(mouseinboard){
            if(!board[mousecell].revealed){
                if(mouse.released(mouse.Button.Right)){
                    board[mousecell].flagged = !board[mousecell].flagged;
                }else if(mouse.released(mouse.Button.Left)){
                    board.reveal(mousecell.x, mousecell.y);
                    if(board.revealedmine){
                        setgameover(State.Lose);
                    }else if(board.revealed + board.mines == board.width * board.height){
                        setgameover(State.Win);
                    }
                }
            }
        }
    }
    
    double gameoverx;
    /// Set game state to Win or Lose
    void setgameover(in State state){
        this.state = state;
        laststate = state;
        gameover = true;
        gameoverx = window.width / 2;
        for(uint i = 0; i < board.width; i++){
            for(uint j = 0; j < board.height; j++){
                board[i, j].revealed = board[i, j].revealed || board[i, j].mined;
            }
        }
    }
    /// Update logic common to Win and Lose game states
    void updategameover(Texture* tex){
        immutable dx = abs(gameoverx - window.width / 2) / (window.width / 2);
        gameoverx += clamp(dx * (window.width * 0.05), 2.0, 7.0);
        if(gameoverx >= window.width + tex.width / 2){
            gameoverx = -(cast(int) tex.width / 2);
        }
        immutable target = Box!double(
            tex.size * (window.height * 0.125 / tex.height)
        ).centered(gameoverx, window.height / 2);
        context.texture(tex, target);
    }
    /// Draw transparent background shown in game over states
    void gameoverbg(){
        context.color = uibackground;
        context.rect(Box!int(window.width, window.height * 0.25).centered(window.size / 2));
    }
    /// Handle win state
    void win(){
        gameoverbg();
        context.color = Color!float(0.2, 1.0, 0.4);
        updategameover(wingraphic);
        if(mouse.released(Mouse.Button.Left)) newgame();
    }
    /// Handle lose state
    void lose(){
        gameoverbg();
        context.color = Color!float(1.0, 0.3, 0.1);
        updategameover(losegraphic);
        if(mouse.released(Mouse.Button.Left)) newgame();
    }
    
    Settings.Size choosesize;
    Settings.Difficulty choosedifficulty;
    /// Handle menu state
    void menu(){
        if(optionsview) optionsmenu();
        else rootmenu();
    }
    /// Handle menu state when viewing the normal root menu
    void rootmenu(){
        context.color = uibackground;
        context.rect(Box!int(window.width, window.height * 2 / 3).centered(window.size / 2));
        immutable bheight = window.height * 0.125;
        immutable bcenter = window.size / 2;
        bool newbutton = menubutton(newgamegraphic,
            Box!double(newgamegraphic.size * (bheight / newgamegraphic.height))
                .centered(bcenter).translated(0, -bheight)
        );
        bool optbutton = menubutton(optionsgraphic,
            Box!double(optionsgraphic.size * (bheight / optionsgraphic.height))
                .centered(bcenter)
        );
        bool quitbutton = menubutton(quitgraphic,
            Box!double(quitgraphic.size * (bheight / quitgraphic.height))
                .centered(bcenter).translated(0, bheight)
        );
        if(newbutton){
            newgame();
        }else if(optbutton){
            optionsview = true;
            choosesize = settings.boardsize;
            choosedifficulty = settings.difficulty;
        }else if(quitbutton){
            quit();
        }
    }
    /// Handle menu state when viewing the options submenu
    void optionsmenu(){
        context.color = uibackground;
        context.rect(Box!int(window.size));
        immutable bheight = window.height * 0.09375;
        immutable bcenter = window.size / 2;
        immutable sizebox = Box!double(sizegraphic.size * (bheight / sizegraphic.height)).centered(bcenter).translated(0, -bheight * 2);
        immutable diffbox = Box!double(diffgraphic.size * (bheight / diffgraphic.height)).centered(bcenter).translated(0, 0);
        bool sizebutton = menubutton(sizegraphic, sizebox);
        bool diffbutton = menubutton(diffgraphic, diffbox);
        bool okbutton = menubutton(okgraphic,
            Box!double(okgraphic.size * (bheight / okgraphic.height))
                .centered(window.width * 0.25, window.height - bheight)
        );
        bool cancelbutton = menubutton(cancelgraphic,
            Box!double(cancelgraphic.size * (bheight / cancelgraphic.height))
                .centered(window.width * 0.75, window.height - bheight)
        );
        static const sizeboxes = [
            0.042, 0.06, 0.078
        ];
        static const diffcolors = [
            Color!float(0.0, 1.0, 0.0),
            Color!float(0.9, 0.78, 0.0),
            Color!float(1.0, 0.25, 0.1),
        ];
        for(int i = 0; i < 3; i++){
            immutable centerx = window.width * 0.5 + (i - 1) * window.width * 0.125;
            // Size
            context.color = Color!float.White * (i == choosesize ? 1.0 : 0.5);
            context.rect(Box!double(window.size * sizeboxes[i]).centered(
                centerx, sizebox.centery + bheight
            )); 
            // Difficulty
            context.color = diffcolors[i] * (i == choosedifficulty ? 1.0 : 0.5);
            context.rect(Box!double(window.size * 0.0625).centered(
                centerx, diffbox.centery + bheight
            ));
        }
        if(sizebutton){
            choosesize = cast(settings.Size)((choosesize + 1) % 3);
        }else if(diffbutton){
            choosedifficulty = cast(settings.Difficulty)((choosedifficulty + 1) % 3);
        }else if(okbutton){
            settings.boardsize = choosesize;
            settings.difficulty = choosedifficulty;
            savesettings();
            if(board.revealed == 0) newgame();
            optionsview = false;
        }else if(cancelbutton){
            optionsview = false;
        }
    }
    /// Draw a menu button and get whether it was clicked
    bool menubutton(T)(Texture* tex, in Box!T target){
        bool clicked = false;
        if(mouse.position in target){
            context.color = Color!float.gray(0.75);
            if(mouse.released(mouse.Button.Left)) clicked = true;
        }else{
            context.color = Color!float.gray(0.98);
        }
        context.texture(tex, target);
        return clicked;
    }
    
    /// Quit the application
    override void quit(QuitReason reason = QuitReason.Unspecified){
        this.quitreason = reason;
        this.quitting = true;
        if(gameover || board.revealed == 0){
            removesavegame();
        }else{
            savegame();
        }
    }
}



void main(){
    new Sweeper().begin;
}
