package pricing

import (
	"math"
	"time"
)

// PricingContext chứa toàn bộ tham số đầu vào cần thiết để định giá
type PricingContext struct {
	ServiceType     string
	DistanceKm      float64
	DurationMin     int
	VehicleType     string // "bike", "car"
	DesignatedMode  string // "solo", "duo"
	ItemsCount      int
	SurgeMultiplier float64
	RequestedAt     time.Time
}

// PricingResult chứa kết quả tính cước chi tiết minh bạch
type PricingResult struct {
	BaseFare        float64            `json:"base_fare"`
	DistanceFare    float64            `json:"distance_fare"`
	TimeFare        float64            `json:"time_fare"`
	ServiceFee      float64            `json:"service_fee"`
	NightSurcharge  float64            `json:"night_surcharge"`
	ShadowDriverFee float64            `json:"shadow_driver_fee"`
	SurgeMultiplier float64            `json:"surge_multiplier"`
	TotalFare       float64            `json:"total_fare"`
	Breakdown       map[string]float64 `json:"breakdown"`
}

// PricingStrategy Interface định nghĩa hành vi tính giá độc lập (Strategy Pattern)
type PricingStrategy interface {
	Calculate(ctx PricingContext) PricingResult
}

// IsNightTime kiểm tra xem thời gian yêu cầu có nằm trong khung giờ đêm (22h - 5h) hay không
func IsNightTime(t time.Time) bool {
	hour := t.Hour()
	return hour >= 22 || hour < 5
}

// RoundToThousand làm tròn cước xe đến hàng nghìn đồng
func RoundToThousand(val float64) float64 {
	return math.Round(val/1000.0) * 1000.0
}
