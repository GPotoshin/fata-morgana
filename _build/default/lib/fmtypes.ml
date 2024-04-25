type time   = int
type radius = int
type point  = (int*int)

type action =
    | DrawLine of point*point*time*time
    | DrawCircle of point*radius*time*time
