package postgres

import (
	"QuitePath/internal/entity"
	"context"
	"database/sql"
	"encoding/json"
	"log"
)

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) GetMapLayers(ctx context.Context) ([]byte, error) {
	// Запрос для пешеходных дорог с уровнями комфорта
	query := `
		SELECT jsonb_build_object(
			'type', 'FeatureCollection',
			'features', COALESCE(jsonb_agg(features.feature), '[]'::jsonb)
		) as geojson
		FROM (
			SELECT jsonb_build_object(
				'type', 'Feature',
				'geometry', ST_AsGeoJSON(w.the_geom)::jsonb,
				'properties', jsonb_build_object(
					'gid', w.gid,
					'name', COALESCE(w.name, 'Без названия'),
					'type', w.tag_value,
					'length_m', ROUND(w.length_m::numeric, 2),
					'comfort_score', ROUND(w.comfort_score::numeric, 2),
					'comfort_level', w.comfort_level,
					'noise_factor', ROUND(w.noise_factor::numeric, 2),
					'green_factor', ROUND(w.green_factor::numeric, 2),
					'building_density', ROUND(w.building_density::numeric, 2)
				)
			) AS feature
			FROM quietpath.pedestrian_ways w
			WHERE 
				w.the_geom IS NOT NULL
				AND ST_Intersects(
					w.the_geom,
					ST_SetSRID(ST_MakeEnvelope(37.60, 55.74, 37.63, 55.76), 4326)
				)
		) features;`

	var geojson json.RawMessage
	err := r.db.QueryRowContext(ctx, query).Scan(&geojson)
	if err != nil {
		log.Printf("❌ SQL Error: %v", err)
		return nil, err
	}
	
	if geojson == nil || len(geojson) == 0 {
		log.Printf("⚠️ Нет данных для центра Москвы")
		return []byte(`{"type":"FeatureCollection","features":[]}`), nil
	}
	
	log.Printf("✅ Загружено пешеходных дорог с комфортом, размер: %d байт", len(geojson))
	return geojson, nil
}

func (r *Repository) GetPath(ctx context.Context, req entity.RouteRequest) ([]entity.Waypoint, error) {
	return []entity.Waypoint{
		{Lat: req.StartLat, Lon: req.StartLon},
		{Lat: req.EndLat, Lon: req.EndLon},
	}, nil
}