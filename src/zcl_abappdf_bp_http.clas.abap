"! HTTP handler of the boarding pass demo. GET ?travel=<id>&booking=<id>
"! returns the boarding pass of that booking as an inline PDF.
CLASS zcl_abappdf_bp_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

  PRIVATE SECTION.
    METHODS query_param
      IMPORTING
        request         TYPE REF TO if_web_http_request
        iv_name         TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.

    METHODS send_text
      IMPORTING
        response TYPE REF TO if_web_http_response
        iv_code  TYPE i
        iv_text  TYPE string.
ENDCLASS.



CLASS zcl_abappdf_bp_http IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.
    DATA lv_travel TYPE /dmo/travel-travel_id.
    DATA lv_booking TYPE /dmo/booking-booking_id.

    DATA(lv_method) = to_upper( request->get_method( ) ).
    IF lv_method <> 'GET' AND lv_method <> 'HEAD'.
      send_text( response = response iv_code = 405 iv_text = `Only GET is supported.` ).
      RETURN.
    ENDIF.

    DATA(lv_travel_text) = query_param( request = request iv_name = `travel` ).
    DATA(lv_booking_text) = query_param( request = request iv_name = `booking` ).
    IF lv_travel_text IS INITIAL OR lv_travel_text CN '0123456789' OR strlen( lv_travel_text ) > 8
        OR lv_booking_text CN '0123456789' OR strlen( lv_booking_text ) > 4.
      send_text( response = response iv_code = 400
                 iv_text = `Use ?travel=<travel ID>&booking=<booking ID>, for example ?travel=2&booking=2.` ).
      RETURN.
    ENDIF.
    lv_travel = lv_travel_text.
    lv_booking = lv_booking_text.

    TRY.
        DATA(lv_pdf) = zcl_abappdf_boarding=>print(
          iv_travel_id  = lv_travel
          iv_booking_id = lv_booking ).
      CATCH zcx_abappdf INTO DATA(lx_error).
        send_text( response = response iv_code = 404 iv_text = lx_error->get_text( ) ).
        RETURN.
    ENDTRY.

    response->set_status( i_code = 200 i_reason = 'OK' ).
    response->set_header_field( i_name = 'content-type' i_value = 'application/pdf' ).
    response->set_header_field(
      i_name  = 'content-disposition'
      i_value = |inline; filename="boarding-pass-{ CONV i( lv_travel ) }-{ lv_booking }.pdf"| ).
    response->set_header_field( i_name = 'cache-control' i_value = 'no-store' ).
    IF lv_method = 'GET'.
      response->set_binary( lv_pdf ).
    ENDIF.
  ENDMETHOD.


  METHOD query_param.
    DATA lt_pairs TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA lv_name TYPE string.
    DATA lv_value TYPE string.

    DATA(lv_uri) = request->get_header_field( '~request_uri' ).
    DATA(lv_q) = find( val = lv_uri sub = '?' ).
    IF lv_q < 0.
      RETURN.
    ENDIF.
    SPLIT substring( val = lv_uri off = lv_q + 1 ) AT '&' INTO TABLE lt_pairs.
    LOOP AT lt_pairs INTO DATA(lv_pair).
      SPLIT lv_pair AT '=' INTO lv_name lv_value.
      IF to_lower( lv_name ) = to_lower( iv_name ).
        rv_value = condense( cl_web_http_utility=>unescape_url( lv_value ) ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD send_text.
    response->set_status( i_code = iv_code i_reason = COND #( WHEN iv_code = 404 THEN `Not Found`
                                                            WHEN iv_code = 405 THEN `Method Not Allowed`
                                                            ELSE `Bad Request` ) ).
    response->set_header_field( i_name = 'content-type' i_value = 'text/plain; charset=utf-8' ).
    response->set_text( iv_text ).
  ENDMETHOD.

ENDCLASS.
