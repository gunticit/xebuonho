package pricing

// GroceryShoppingStrategy triển khai thuật toán tính phí dịch vụ đi chợ hộ (mua hộ, lựa chọn đồ)
type GroceryShoppingStrategy struct{}

func NewGroceryShoppingStrategy() *GroceryShoppingStrategy {
	return &GroceryShoppingStrategy{}
}

func (s *GroceryShoppingStrategy) Calculate(ctx PricingContext) PricingResult {
	// Phí công mua hộ căn bản
	conciergeFee := 25000.0
	if ctx.ItemsCount > 10 {
		conciergeFee += float64(ctx.ItemsCount-10) * 2000.0 // phí chọn đồ cồng kềnh
	}

	// Phí vận chuyển giao hàng
	baseDelivery := 15000.0
	perKm := 6000.0
	distKm := ctx.DistanceKm
	if distKm < 1.0 {
		distKm = 1.0
	}

	distFee := 0.0
	if distKm > 2.0 {
		distFee = (distKm - 2.0) * perKm
	}

	subtotal := conciergeFee + baseDelivery + distFee

	nightSurcharge := 0.0
	if IsNightTime(ctx.RequestedAt) {
		nightSurcharge = 15000.0
	}

	total := RoundToThousand(subtotal + nightSurcharge)

	return PricingResult{
		BaseFare:       baseDelivery,
		DistanceFare:   RoundToThousand(distFee),
		ServiceFee:     conciergeFee,
		NightSurcharge: nightSurcharge,
		TotalFare:      total,
		Breakdown: map[string]float64{
			"delivery_base":   baseDelivery,
			"distance_fare":   RoundToThousand(distFee),
			"concierge_fee":   conciergeFee,
			"night_surcharge": nightSurcharge,
		},
	}
}
