package http

import (
	"QuitePath/internal/entity"
	"QuitePath/internal/usecase"
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	uc *usecase.Navigator
}

func NewHandler(uc *usecase.Navigator) *Handler {
	return &Handler{uc: uc}
}

func (h *Handler) GetRoute(c *gin.Context) {
	var req entity.RouteRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad params"})
		return
	}

	res, err := h.uc.FindRoute(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, res)
}

func (h *Handler) GetMapLayers(c *gin.Context) {
	res, err := h.uc.GetMapData(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	
	// Парсим байты в JSON объект
	var geojson interface{}
	if err := json.Unmarshal(res, &geojson); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "invalid geojson"})
		return
	}
	
	c.JSON(http.StatusOK, geojson)
}