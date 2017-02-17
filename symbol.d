import mach.sdl;
import mach.math;



/// Represents a symbol to be rendered onto the board.
struct Symbol{
    static enum Zero = Symbol([
        Box!float(0.4, 1.0).at(0.0, 0.0),
        Box!float(0.4, 1.0).at(0.6, 0.0),
        Box!float(0.4, 0.2).at(0.4, 0.0),
        Box!float(0.4, 0.2).at(0.4, 0.8),
    ]);
    static enum One = Symbol([
        Box!float(0.4, 1.0).at(0.3, 0.0),
        Box!float(0.3, 0.2).at(0.0, 0.0),
        Box!float(1.0, 0.2).at(0.0, 0.8),
    ]);
    static enum Two = Symbol([
        Box!float(1.0, 0.2).at(0.0, 0.0),
        Box!float(1.0, 0.2).at(0.0, 0.4),
        Box!float(1.0, 0.2).at(0.0, 0.8),
        Box!float(0.4, 0.2).at(0.6, 0.2),
        Box!float(0.4, 0.2).at(0.0, 0.6),
    ]);
    static enum Three = Symbol([
        Box!float(1.0, 0.2).at(0.0, 0.0),
        Box!float(0.6, 0.2).at(0.2, 0.4),
        Box!float(1.0, 0.2).at(0.0, 0.8),
        Box!float(0.4, 0.6).at(0.6, 0.2),
    ]);
    static enum Four = Symbol([
        Box!float(0.4, 0.6).at(0.0, 0.0),
        Box!float(0.4, 1.0).at(0.6, 0.0),
        Box!float(0.2, 0.2).at(0.4, 0.4),
    ]);
    static enum Five = Symbol([
        Box!float(1.0, 0.2).at(0.0, 0.0),
        Box!float(1.0, 0.2).at(0.0, 0.4),
        Box!float(1.0, 0.2).at(0.0, 0.8),
        Box!float(0.4, 0.2).at(0.0, 0.2),
        Box!float(0.4, 0.2).at(0.6, 0.6),
    ]);
    static enum Six = Symbol([
        Box!float(1.0, 0.2).at(0.0, 0.0),
        Box!float(1.0, 0.2).at(0.0, 0.8),
        Box!float(0.4, 0.6).at(0.0, 0.2),
        Box!float(0.4, 0.4).at(0.6, 0.4),
        Box!float(0.2, 0.2).at(0.4, 0.4),
    ]);
    static enum Seven = Symbol([
        Box!float(1.0, 0.2).at(0.0, 0.0),
        Box!float(0.4, 0.8).at(0.6, 0.2),
    ]);
    static enum Eight = Symbol([
        Box!float(1.0, 0.2).at(0.0, 0.0),
        Box!float(0.6, 0.2).at(0.2, 0.4),
        Box!float(1.0, 0.2).at(0.0, 0.8),
        Box!float(0.4, 0.6).at(0.0, 0.2),
        Box!float(0.4, 0.6).at(0.6, 0.2),
    ]);
    static enum Bang = Symbol([
        Box!float(0.4, 0.6).at(0.3, 0.0),
        Box!float(0.4, 0.2).at(0.3, 0.8),
        
    ]);
    
    Box!float[] parts;
    
    static auto gettarget(X, Y)(in Box!X target, in Box!Y part){
        return Box!X(
            target.topleft + (part.topleft * target.size),
            target.topleft + (part.bottomright * target.size)
        );
    }
    
    void render(T, C)(Surface* surface, in Color!C color, in Box!T target) const{
        foreach(part; this.parts){
            surface.fill(this.gettarget(target, part), color);
        }
    }
    void render(T)(RenderContext context, in Box!T target) const{
        foreach(part; this.parts){
            context.rect(this.gettarget(target, part));
        }
    }
}
