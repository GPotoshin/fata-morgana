type time   = int
type point  = (int*int)
type color  = (int*int*int)

type action =
    | DrawCircle of point*color*int*int*time*time
