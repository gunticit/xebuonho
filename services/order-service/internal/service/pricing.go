package service

import (
	"math"
)

// PricingEngine calculates prices for all service types
type PricingEngine struct{}

// NewPricingEngine creates a new pricing engine
func NewPricingEngine() *PricingEngine {
	return &PricingEngine{}
}

// RideFareConfig holds fare configuration per vehicle type
type RideFareConfig struct {
	BaseFare       float64
	PricePerKm     float64
	PricePerMinute float64
	MinFare        float64
	PlatformFee    float64
	Tier1Km        float64
	Tier1Price     float64
	Tier2Km        float64
	Tier2Price     float64
	Tier3Price     float64
}

var rideFareConfigs = map[string]RideFareConfig{
	"bike": {
		BaseFare: 12000, PricePerKm: 4200, PricePerMinute: 300,
		MinFare: 12000, PlatformFee: 2000,
		Tier1Km: 2, Tier1Price: 5000, Tier2Km: 30, Tier2Price: 4200, Tier3Price: 3800,
	},
	"car": {
		BaseFare: 25000, PricePerKm: 9500, PricePerMinute: 500,
		MinFare: 25000, PlatformFee: 3000,
		Tier1Km: 2, Tier1Price: 12000, Tier2Km: 30, Tier2Price: 9500, Tier3Price: 8500,
	},
	"premium": {
		BaseFare: 35000, PricePerKm: 14000, PricePerMinute: 800,
		MinFare: 35000, PlatformFee: 5000,
		Tier1Km: 2, Tier1Price: 16000, Tier2Km: 30, Tier2Price: 14000, Tier3Price: 12000,
	},
}

// PriceBreakdown holds the full pricing breakdown
type PriceBreakdown struct {
	BaseFare        float64 `json:"base_fare"`
	DistanceFare    float64 `json:"distance_fare"`
	TimeFare        float64 `json:"time_fare"`
	ItemsTotal      float64 `json:"items_total"`
	DeliveryFee     float64 `json:"delivery_fee"`
	ServiceFee      float64 `json:"service_fee"`
	PackagingFee    float64 `json:"packaging_fee"`
	SurgeMultiplier float64 `json:"surge_multiplier"`
	SurgeAmount     float64 `json:"surge_amount"`
	ShadowDriverFee float64 `json:"shadow_driver_fee"`
	NightSurcharge  float64 `json:"night_surcharge"`
	Discount        float64 `json:"discount"`
	PlatformFee     float64 `json:"platform_fee"`
	TotalEstimate   float64 `json:"total_estimate"`
	Currency        string  `json:"currency"`
}

// CalculateRideFare calculates the fare for a ride
func (p *PricingEngine) CalculateRideFare(vehicleType string, distanceKm float64, durationMin int, surgeMultiplier float64) PriceBreakdown {
	config, ok := rideFareConfigs[vehicleType]
	if !ok {
		config = rideFareConfigs["car"]
	}

	// Tiered distance pricing
	var distanceFare float64
	remaining := distanceKm
	if remaining > 0 {
		tier1 := math.Min(remaining, config.Tier1Km)
		distanceFare += tier1 * config.Tier1Price
		remaining -= tier1
	}
	if remaining > 0 {
		tier2 := math.Min(remaining, config.Tier2Km-config.Tier1Km)
		distanceFare += tier2 * config.Tier2Price
		remaining -= tier2
	}
	if remaining > 0 {
		distanceFare += remaining * config.Tier3Price
	}

	timeFare := float64(durationMin) * config.PricePerMinute
	subtotal := config.BaseFare + distanceFare + timeFare

	if surgeMultiplier <= 0 {
		surgeMultiplier = 1.0
	}
	surgeAmount := subtotal * (surgeMultiplier - 1)

	total := subtotal + surgeAmount + config.PlatformFee
	total = math.Max(total, config.MinFare)
	total = math.Ceil(total/1000) * 1000 // Round up to 1000 VND

	return PriceBreakdown{
		BaseFare:        config.BaseFare,
		DistanceFare:    distanceFare,
		TimeFare:        timeFare,
		SurgeMultiplier: surgeMultiplier,
		SurgeAmount:     surgeAmount,
		PlatformFee:     config.PlatformFee,
		TotalEstimate:   total,
		Currency:        "VND",
	}
}

// CalculateFoodDeliveryFee calculates fee for food delivery
func (p *PricingEngine) CalculateFoodDeliveryFee(itemsTotal, distanceKm float64, surgeMultiplier float64) PriceBreakdown {
	// Delivery fee based on distance
	var deliveryFee float64
	if distanceKm <= 3 {
		deliveryFee = 15000
	} else if distanceKm <= 7 {
		deliveryFee = 15000 + (distanceKm-3)*4000
	} else {
		deliveryFee = 31000 + (distanceKm-7)*3500
	}

	// Packaging fee (3% of items, min 2000, max 10000)
	packagingFee := math.Max(2000, math.Min(itemsTotal*0.03, 10000))

	// Platform fee
	platformFee := 3000.0

	if surgeMultiplier <= 0 {
		surgeMultiplier = 1.0
	}
	surgeAmount := deliveryFee * (surgeMultiplier - 1)

	total := itemsTotal + deliveryFee + surgeAmount + packagingFee + platformFee
	total = math.Ceil(total/1000) * 1000

	return PriceBreakdown{
		ItemsTotal:      itemsTotal,
		DeliveryFee:     deliveryFee,
		PackagingFee:    packagingFee,
		SurgeMultiplier: surgeMultiplier,
		SurgeAmount:     surgeAmount,
		PlatformFee:     platformFee,
		TotalEstimate:   total,
		Currency:        "VND",
	}
}

// CalculateGroceryFee calculates fee for grocery shopping
func (p *PricingEngine) CalculateGroceryFee(estimatedItemsTotal, distanceKm float64) PriceBreakdown {
	// Service fee (15-20% of items, min 20000)
	serviceFee := math.Max(20000, estimatedItemsTotal*0.15)

	// Delivery fee
	var deliveryFee float64
	if distanceKm <= 5 {
		deliveryFee = 20000
	} else {
		deliveryFee = 20000 + (distanceKm-5)*4000
	}

	platformFee := 3000.0
	total := estimatedItemsTotal + serviceFee + deliveryFee + platformFee
	total = math.Ceil(total/1000) * 1000

	return PriceBreakdown{
		ItemsTotal:    estimatedItemsTotal,
		ServiceFee:    serviceFee,
		DeliveryFee:   deliveryFee,
		PlatformFee:   platformFee,
		TotalEstimate: total,
		Currency:      "VND",
	}
}

// CalculateDesignatedDriverFare calculates fare for designated driver
func (p *PricingEngine) CalculateDesignatedDriverFare(distanceKm float64, durationMin int, isDuo, isNight bool) PriceBreakdown {
	// Higher base fare and rates (1.5x regular ride)
	baseFare := 50000.0
	ratePerKm := 14250.0 // 9500 × 1.5
	ratePerMin := 750.0  // 500 × 1.5

	distanceFare := distanceKm * ratePerKm
	timeFare := float64(durationMin) * ratePerMin

	// Shadow driver fee
	var shadowFee float64
	if isDuo {
		shadowFee = 30000 + distanceKm*5000 // Base + per km for the follower
	}

	// Night surcharge (22h-6h): +30%
	var nightSurcharge float64
	if isNight {
		nightSurcharge = (baseFare + distanceFare + timeFare) * 0.30
	}

	platformFee := 5000.0
	total := baseFare + distanceFare + timeFare + shadowFee + nightSurcharge + platformFee
	total = math.Ceil(total/1000) * 1000

	return PriceBreakdown{
		BaseFare:        baseFare,
		DistanceFare:    distanceFare,
		TimeFare:        timeFare,
		ShadowDriverFee: shadowFee,
		NightSurcharge:  nightSurcharge,
		PlatformFee:     platformFee,
		TotalEstimate:   total,
		Currency:        "VND",
	}
}
