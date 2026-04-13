package entity

type RouteRequest struct {
	StartLat float64 `form:"s_lat"`
	StartLon float64 `form:"s_lon"`
	EndLat   float64 `form:"e_lat"`
	EndLon   float64 `form:"e_lon"`
}

type Waypoint struct {
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
}