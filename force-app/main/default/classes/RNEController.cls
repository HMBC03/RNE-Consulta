public with sharing class RNEController {

    // Clase para estructurar la respuesta hacia el LWC
    public class RNE_Result {
        @AuraEnabled public Boolean found;         // Si se encontró en la base de datos 
        @AuraEnabled public String message;        // Mensaje para el usuario
        @AuraEnabled public String rawResponse;    // Respuesta cruda por si acaso
        @AuraEnabled public Map<String, Boolean> contactOptions; // Opciones (sms, llamada, etc)
    }

    @AuraEnabled
    public static RNE_Result consultarRNE(String dato, String tipo) {
        RNE_Result resultado = new RNE_Result();
        resultado.contactOptions = new Map<String, Boolean>();
        
        // 1. Obtener Token (Recuerde que debe haber creado la etiqueta RNE_Auth_Token)
        String token = System.Label.RNE_Auth_Token;
        
        // 2. Preparar el JSON del Request según la documentación
        // DONDE, 'keys' es un arreglo de strings
        Map<String, Object> jsonBody = new Map<String, Object>();
        
        if (tipo == 'TELEFONO') {
            jsonBody.put('type', 'TEL'); //
        } else {
            jsonBody.put('type', 'COR'); //
        }
        
        // Aunque consultamos uno solo, la API pide una lista PUEDE CONFIGURARSE PARA MASIVOS RESPETANDO LOS LIMITES ESPECIFICADOS 
        jsonBody.put('keys', new List<String>{ dato }); 

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        // 3. Configurar la URL exacta dada en la documentación de la CRC 
        request.setEndpoint('https://tramitescrcom.gov.co/excluidosback/consultaMasiva/validarExcluidos');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', 'Bearer ' + token); // SE INCLUYE EL Bearer token para autenticación
        request.setBody(JSON.serialize(jsonBody));
        request.setTimeout(120000);

        try {
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                // La respuesta es una lista de objetos por tanto procesamos como tal y deseralizamos 
                List<Object> responseList = (List<Object>) JSON.deserializeUntyped(response.getBody());
                
                if (responseList != null && !responseList.isEmpty()) {
                    // Tomamos el primer resultado aqui solo enviamos un key pero si fuera masivo habria varios y tocaria modificar la logica
                    Map<String, Object> data = (Map<String, Object>) responseList[0];
                    
                    resultado.found = true;
                    resultado.message = 'El registro se encuentra en la base de datos de excluidos.';
                    
                    // Extraemos las opciones de contacto
                    if (data.containsKey('opcionesContacto')) {
                        Map<String, Object> opciones = (Map<String, Object>) data.get('opcionesContacto');
                        
                        // Convertimos a mapa de Booleanos para el LWC
                        for(String key : opciones.keySet()) {
                            resultado.contactOptions.put(key, (Boolean)opciones.get(key));
                        }
                    }
                } else {
                    // Si la lista está vacía, significa que no está en la base de datos de excluidos o no existe no se hace valiacion porque seria logica inecesaria
                    resultado.found = false;
                    resultado.message = 'El dato no se encuentra en la lista de excluidos (Permitido contactar).';
                }
            } else {
                resultado.found = false;
                resultado.message = 'Error del servicio: ' + response.getStatus() + ' ' + response.getBody();
            }
        } catch (Exception e) {
            resultado.found = false;
            resultado.message = 'Error de conexión: ' + e.getMessage();
        }

        return resultado;
    }
}