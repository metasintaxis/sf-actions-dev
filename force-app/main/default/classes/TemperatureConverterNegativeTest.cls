@IsTest
public with sharing class TemperatureConverterNegativeTest {
	@IsTest
	static void testWarmTemp() {
		//GIVEN
		Decimal initialTemp = 70;
		//WHEN
		Test.startTest();
		Decimal celsius = TemperatureConverter.fahrenheitToCelsius(
			initialTemp
		);
		Test.stopTest();
		//THEN
		Assert.areEqual(21.11, celsius);
	}
	@IsTest
	static void testFreezingPoint() {
		//GIVEN
		Decimal initialTemp = 32;
		//WHEN
		Test.startTest();
		Decimal celsius = TemperatureConverter.FahrenheitToCelsius(
			initialTemp
		);
		Test.stopTest();
		//THEN
		Assert.areEqual(0, celsius);
	}
	@IsTest
	static void testBoilingPoint() {
		//GIVEN
		Decimal initialTemp = 212;
		//WHEN
		Test.startTest();
		Decimal celsius = TemperatureConverter.FahrenheitToCelsius(
			initialTemp
		);
		Test.stopTest();
		//THEN
		Assert.areEqual(
			100,
			celsius,
			'Boiling point temperature is not expected.'
		);
	}
	@IsTest
	static void testNegativeTemp() {
		//GIVEN
		Decimal initialTemp = -10;
		//WHEN
		Test.startTest();
		Decimal celsius = TemperatureConverter.FahrenheitToCelsius(
			initialTemp
		);
		Test.stopTest();
		//THEN
		Assert.areEqual(-23.33, celsius);
	}
}
