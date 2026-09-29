System.debug('=== EIA API TEST ===');

// Test retail price fetch (Gasoline)
String endpoint = 'https://api.eia.gov/v2/petroleum/pri/gnd/data/';
String params = 'api_key=E4TDjm24q77B0j83z1IgFL7Ow2UcuishRY4A61HD&frequency=weekly&data[0]=value&facets[product][]=EPM0&facets[duoarea][]=NUS&facets[process][]=PTE&sort[0][column]=period&sort[0][direction]=desc&length=1';

Http http = new Http();
HttpRequest req = new HttpRequest();
req.setEndpoint(endpoint + '?' + params);
req.setMethod('GET');
req.setTimeout(15000);

HttpResponse res = http.send(req);
System.debug('Price API Status: ' + res.getStatusCode());

if (res.getStatusCode() == 200) {
    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    Map<String, Object> response = (Map<String, Object>) responseMap.get('response');
    List<Object> data = (List<Object>) response.get('data');
    Map<String, Object> record = (Map<String, Object>) data[0];
    System.debug('=== RETAIL PRICE RESULT ===');
    System.debug('Product: ' + record.get('product-name'));
    System.debug('Price: $' + record.get('value') + ' ' + record.get('units'));
    System.debug('Date: ' + record.get('period'));
} else {
    System.debug('PRICE API ERROR: ' + res.getBody());
}

// Test stock fetch (Crude Oil)
endpoint = 'https://api.eia.gov/v2/petroleum/stoc/wstk/data/';
params = 'api_key=E4TDjm24q77B0j83z1IgFL7Ow2UcuishRY4A61HD&frequency=weekly&data[0]=value&facets[product][]=EPC0&facets[duoarea][]=NUS&facets[process][]=SAE&sort[0][column]=period&sort[0][direction]=desc&length=1';

req.setEndpoint(endpoint + '?' + params);
res = http.send(req);
System.debug('Stock API Status: ' + res.getStatusCode());

if (res.getStatusCode() == 200) {
    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    Map<String, Object> response = (Map<String, Object>) responseMap.get('response');
    List<Object> data = (List<Object>) response.get('data');
    Map<String, Object> record = (Map<String, Object>) data[0];
    System.debug('=== STOCK RESULT ===');
    System.debug('Product: ' + record.get('product-name'));
    System.debug('Stocks: ' + record.get('value') + ' ' + record.get('units'));
    System.debug('Date: ' + record.get('period'));
} else {
    System.debug('STOCK API ERROR: ' + res.getBody());
}

// Test Diesel price
endpoint = 'https://api.eia.gov/v2/petroleum/pri/gnd/data/';
params = 'api_key=E4TDjm24q77B0j83z1IgFL7Ow2UcuishRY4A61HD&frequency=weekly&data[0]=value&facets[product][]=EPD2DXL0&facets[duoarea][]=NUS&facets[process][]=PTE&sort[0][column]=period&sort[0][direction]=desc&length=1';

req.setEndpoint(endpoint + '?' + params);
res = http.send(req);

if (res.getStatusCode() == 200) {
    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    Map<String, Object> response = (Map<String, Object>) responseMap.get('response');
    List<Object> data = (List<Object>) response.get('data');
    Map<String, Object> record = (Map<String, Object>) data[0];
    System.debug('=== DIESEL PRICE RESULT ===');
    System.debug('Product: ' + record.get('product-name'));
    System.debug('Price: $' + record.get('value') + ' ' + record.get('units'));
    System.debug('Date: ' + record.get('period'));
}

// Test Gasoline Stocks
endpoint = 'https://api.eia.gov/v2/petroleum/stoc/wstk/data/';
params = 'api_key=E4TDjm24q77B0j83z1IgFL7Ow2UcuishRY4A61HD&frequency=weekly&data[0]=value&facets[product][]=EPM0&facets[duoarea][]=NUS&facets[process][]=SAE&sort[0][column]=period&sort[0][direction]=desc&length=1';

req.setEndpoint(endpoint + '?' + params);
res = http.send(req);

if (res.getStatusCode() == 200) {
    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    Map<String, Object> response = (Map<String, Object>) responseMap.get('response');
    List<Object> data = (List<Object>) response.get('data');
    Map<String, Object> record = (Map<String, Object>) data[0];
    System.debug('=== GASOLINE STOCKS RESULT ===');
    System.debug('Product: ' + record.get('product-name'));
    System.debug('Stocks: ' + record.get('value') + ' ' + record.get('units'));
    System.debug('Date: ' + record.get('period'));
}

System.debug('=== EIA TEST COMPLETE ===');
