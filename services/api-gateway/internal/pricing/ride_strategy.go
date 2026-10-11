package pricing

// StandardRideStrategy triển khai thuật toán tính cước cho dịch vụ đặt xe thông thường (Xe máy / Ô tô)
type StandardRideStrategy struct{}

func NewStandardRideStrategy() *StandardRideStrategy {
	return &StandardRideStrategy{}
}

func (s *StandardRideStrategy) Calculate(ctx PricingContext) PricingResult {
	var baseFare, perKmRate, perMinRate float64

	if ctx.VehicleType == "car" {
		baseFare = 25000 // 2km đầu
		perKmRate = 12000
		perMinRate = 600
	} else {
		// bike
		baseFare = 14000 // 2km đầu
		perKmRate = 5000
		perMinRate = 300
	}

	distKm := ctx.DistanceKm
	if distKm < 1.0 {
		distKm = 1.0
	}

	distanceFare := 0.0
	if distKm > 2.0 {
		distanceFare = (distKm - 2.0) * perKmRate
	}

	durMin := ctx.DurationMin
	if durMin < 5 {
		durMin = 5
	}
	timeFare := float64(durMin) * perMinRate

	subtotal := baseFare + distanceFare + timeFare

	surge := ctx.SurgeMultiplier
	if surge < 1.0 {
		surge = 1.0
	}
	subtotal *= surge

	nightSurcharge := 0.0
	if IsNightTime(ctx.RequestedAt) {
		nightSurcharge = subtotal * 0.20 // +20% phụ phí ban đêm
	}

	total := RoundToThousand(subtotal + nightSurcharge)

	return PricingResult{
		BaseFare:        baseFare,
		DistanceFare:    RoundToThousand(distanceFare),
		TimeFare:        RoundToThousand(timeFare),
		SurgeMultiplier: surge,
		NightSurcharge:  RoundToThousand(nightSurcharge),
		TotalFare:       total,
		Breakdown: map[string]float64{
			"base_fare":       baseFare,
			"distance_fare":   RoundToThousand(distanceFare),
			"time_fare":       RoundToThousand(timeFare),
			"night_surcharge": RoundToThousand(nightSurcharge),
		},
	}
}
