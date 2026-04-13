package usecase

import (
	"QuitePath/internal/entity"
	"context"
)

type Repo interface {
	GetPath(ctx context.Context, req entity.RouteRequest) ([]entity.Waypoint, error)
	GetMapLayers(ctx context.Context) ([]byte, error)
}

type Navigator struct {
	repo Repo
}

func NewNavigator(r Repo) *Navigator {
	return &Navigator{repo: r}
}

func (n *Navigator) FindRoute(ctx context.Context, req entity.RouteRequest) ([]entity.Waypoint, error) {
	return n.repo.GetPath(ctx, req)
}

func (n *Navigator) GetMapData(ctx context.Context) ([]byte, error) {
    return n.repo.GetMapLayers(ctx)
}