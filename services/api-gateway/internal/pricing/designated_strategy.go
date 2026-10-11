package pricing

// DesignatedDriverStrategy triển khai tính giá dịch vụ Lái Xe Hộ (khách say rượu / cần tài xế riêng)
type DesignatedDriverStrategy struct{}

func NewDesignatedDriverStrategy() *DesignatedDriverStrategy {
	return &DesignatedDriverStrategy{}
}

func (s *DesignatedDriverStrategy) Calculate(ctx PricingContext) PricingResult {
	var baseFare, perKmRate float64

	// Phí phụ thuộc vào loại xe của khách
	if ctx.VehicleType == "bike" {
		baseFare = 60000.0 // 3km đầu
		perKmRate = 12000.0
	} else {
		// car (hạng sang hoặc phổ thông)
		baseFare = 150000.0 // 3km đầu
		perKmRate = 22000.0
	}

	distKm := ctx.DistanceKm
	if distKm < 1.0 {
		distKm = 1.0
	}

	distFee := 0.0
	if distKm > 3.0 {
		distFee = (distKm - 3.0) * perKmRate
	}

	// Chế độ Shadow Driver (Duo vs Solo)
	shadowDriverFee := 0.0
	if ctx.DesignatedMode == "duo" {
		// Duo mode: có tài xế phụ chạy xe máy đi kè để đón tài xế chính về
		shadowDriverFee = RoundToThousand(baseFare*0.6 + distKm*5000)
	}

	subtotal := baseFare + distFee + shadowDriverFee

	// Phụ phí ban đêm (Dịch vụ lái xe hộ đặc thù thường hoạt động ban đêm từ 22h-5h sáng)
	nightSurcharge := 0.0
	if IsNightTime(ctx.RequestedAt) {
		nightSurcharge = subtotal * 0.30 // +30% phụ phí đêm
	}

	total := RoundToThousand(subtotal + nightSurcharge)

	return PricingResult{
		BaseFare:        baseFare,
		DistanceFare:    RoundToThousand(distFee),
		ShadowDriverFee: shadowDriverFee,
		NightSurcharge:  RoundToThousand(nightSurcharge),
		TotalFare:       total,
		Breakdown: map[string]float64{
			"base_fare":         baseFare,
			"distance_fare":     RoundToThousand(distFee),
			"shadow_driver_fee": shadowDriverFee,
			"night_surcharge":   RoundToThousand(nightSurcharge),
		},
	}
}
