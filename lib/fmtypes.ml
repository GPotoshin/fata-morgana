type time = int
type point = (int*int)

type action =
    | DrawLine of point*point*time
    | DrawCircle of point*int*time
