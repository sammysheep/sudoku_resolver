#!./make.py
from time import now
from math import iota
from algorithm import parallelize

#INFO: the simple algo, with specialized types & parallelization

alias GROUP = SIMD[DType.uint8, 16]   # reality is 9, but should be a **2 .. so 16 !

struct Grid:
    var data: Buffer[81, DType.uint8]

    fn __init__(inout self:Grid, g:String) -> None:
        "Create from a string (of 81 chars)."
        let dtp = DTypePointer[DType.uint8].alloc(81)
        self.data = Buffer[81, DType.uint8](dtp)
        let ptr = g._buffer.data.bitcast[UInt8]()
        @unroll
        for idx in range(81):
            self.data[idx] = ptr[idx]-48 if ptr[idx]!=46 else 0
        _=g

    fn sqr(self:Grid,x:Int,y:Int) -> GROUP:
        'Returns a group of 9 values, of the square at x,y.'
        let off=y*9+x
        var group=GROUP().splat(0)
        @unroll
        for i in range(3):
            group[i]=self.data[off+i]
            group[i+3]=self.data[off+i+9]
            group[i+6]=self.data[off+i+18]
        return group

    fn col(self:Grid,x:Int) -> GROUP:
        'Returns a group of 9 values, of the column x.'
        var group=GROUP().splat(0)
        @unroll
        for i in range(9):
            group[i]=self.data[i*9+x]
        return group

    fn row(self:Grid,y:Int) -> GROUP:
        'Returns a group of 9 values, of the row y.'
        let off=y*9
        var group=GROUP().splat(0)
        @unroll
        for i in range(9):
            group[i]=self.data[off+i]
        return group

    fn free(self: Grid, x: Int, y: Int) -> InlinedFixedVector[UInt8,9]:
        "Returns a list of available values that can be fit in (x,y)."
        "(this thing is a bit tricky coz it uses simd operation, to be as fast as possible)"
        let _s = self.sqr((x // 3) * 3, (y // 3) * 3)
        let _c = self.col(x)
        let _r = self.row(y)

        var avails = InlinedFixedVector[UInt8,9](9)

        @unroll
        for c in range(1, 10):
            if (
                (not (_s == c).reduce_or())
                and (not (_c == c).reduce_or())
                and (not (_r == c).reduce_or())
            ):
                # no C in row/col/sqr
                avails.append(c)
        return avails

    fn solve(self: Grid) -> Bool:
        "Solve the grid, returns true/false if it cans."
        "It's the simple algo : so it tries always the first hole."
        for i in range(81):
            if self.data[i]==0:
                let ll=self.free(i%9,i//9)
                for idx in range(len(ll)):
                    self.data[i]=ll[idx].__int__()
                    if self.solve(): 
                        return True
                self.data[i]=0
                return False
        return True

    fn to_string(self:Grid) -> String:
        "Returns a string of 81chars of the grid."
        var str=String("")
        @unroll
        for i in range(81):
            let c = self.data[i].__int__()
            str+= chr(48+c)[0] if c else "."
        return str           


fn main() raises:
    let buf = open("grids.txt", "r").read()
    let t=now()

    @parameter
    fn in_p(i:Int):
        let g=Grid(buf[i*82:i*82+81])
        print( g.solve() and g.to_string() )

    parallelize[in_p](100,100) #more workers to distribute the effort on cores
    print("Took:",(now() - t)/1_000_000_000,"s")
    
    _=buf^ #extend lifetime of pointer
