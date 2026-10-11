package pricing

// FoodDeliveryStrategy triển khai thuật toán tính phí vận chuyển thức ăn từ quán đến khách
type FoodDeliveryStrategy struct{}

func NewFoodDeliveryStrategy() *FoodDeliveryStrategy {
	return &FoodDeliveryStrategy{}
}

func (s *FoodDeliveryStrategy) Calculate(ctx PricingContext) PricingResult {
	baseDeliveryFee := 16000.0 // 2km đầu tiên
	perKmRate := 5000.0        // sau 2km

	distKm := ctx.DistanceKm
	if distKm < 1.0 {
		distKm = 1.0
	}

	distanceFare := 0.0
	if distKm > 2.0 {
		distanceFare = (distKm - 2.0) * perKmRate
	}

	packingFee := 3000.0 // Phí đóng gói chuẩn bị
	if ctx.ItemsCount > 5 {
		packingFee += float64(ctx.ItemsCount-5) * 1000.0
	}

	subtotal := baseDeliveryFee + distanceFare + packingFee

	surge := ctx.SurgeMultiplier
	if surge < 1.0 {
		surge = 1.0
	}
	subtotal *= surge

	nightSurcharge := 0.0
	if IsNightTime(ctx.RequestedAt) {
		nightSurcharge = 8000.0 // Phí ship đêm cố định
	}

	total := RoundToThousand(subtotal + nightSurcharge)

	return PricingResult{
		BaseFare:        baseDeliveryFee,
		DistanceFare:    RoundToThousand(distanceFare),
		ServiceFee:      packingFee,
		NightSurcharge:  RoundToThousand(nightSurcharge),
		SurgeMultiplier: surge,
		TotalFare:       total,
		Breakdown: map[string]float64{
			"delivery_base":   baseDeliveryFee,
			"distance_fare":   RoundToThousand(distanceFare),
			"packing_fee":     packingFee,
			"night_surcharge": RoundToThousand(nightSurcharge),
		},
	}
}
