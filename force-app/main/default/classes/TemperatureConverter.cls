public with sharing class TemperatureConverter {
	// Takes a Fahrenheit temperature and returns the Celsius equivalent.
	public static Decimal fahrenheitToCelsius(Decimal fahrenheit) {
		Decimal celsius = (fahrenheit - 32) * 5 / 9;
		return celsius.setScale(2);
	}
}
