package pricing

import "fmt"

// PricingFactory (Factory Pattern) chịu trách nhiệm khởi tạo và cung cấp Strategy tương ứng với loại dịch vụ
type PricingFactory struct {
	rideStrategy       *StandardRideStrategy
	foodStrategy       *FoodDeliveryStrategy
	groceryStrategy    *GroceryShoppingStrategy
	designatedStrategy *DesignatedDriverStrategy
}

var defaultFactory *PricingFactory

func init() {
	defaultFactory = NewPricingFactory()
}

func NewPricingFactory() *PricingFactory {
	return &PricingFactory{
		rideStrategy:       NewStandardRideStrategy(),
		foodStrategy:       NewFoodDeliveryStrategy(),
		groceryStrategy:    NewGroceryShoppingStrategy(),
		designatedStrategy: NewDesignatedDriverStrategy(),
	}
}

// GetStrategy trả về PricingStrategy thích hợp dựa trên serviceType
func (f *PricingFactory) GetStrategy(serviceType string) (PricingStrategy, error) {
	switch serviceType {
	case "ride", "":
		return f.rideStrategy, nil
	case "food_delivery":
		return f.foodStrategy, nil
	case "grocery":
		return f.groceryStrategy, nil
	case "designated_driver":
		return f.designatedStrategy, nil
	default:
		return nil, fmt.Errorf("không hỗ trợ tính cước cho dịch vụ: %s", serviceType)
	}
}

// CalculatePrice hàm tiện ích tĩnh (Facade) tính giá nhanh
func CalculatePrice(ctx PricingContext) (PricingResult, error) {
	strategy, err := defaultFactory.GetStrategy(ctx.ServiceType)
	if err != nil {
		return PricingResult{}, err
	}
	return strategy.Calculate(ctx), nil
}
