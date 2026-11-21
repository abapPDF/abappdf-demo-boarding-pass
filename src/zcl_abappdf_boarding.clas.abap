"! Boarding pass demo: prints form ZPDF_BOARDING_PASS for one booking of the
"! flight model (/DMO). Gate, seat and boarding time are not part of /DMO, so
"! they are derived from the booking to give realistic demo values.
CLASS zcl_abappdf_boarding DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    CONSTANTS c_form_id TYPE string VALUE `ZPDF_BOARDING_PASS`.

    TYPES:
      BEGIN OF ty_pass,
        travel_id      TYPE string,
        booking_ref    TYPE string,
        passenger_name TYPE string,
        carrier_id     TYPE string,
        carrier_name   TYPE string,
        connection_id  TYPE string,
        from_airport   TYPE string,
        from_city      TYPE string,
        to_airport     TYPE string,
        to_city        TYPE string,
        flight_date    TYPE string,
        departure_time TYPE string,
        arrival_time   TYPE string,
        distance       TYPE string,
        boarding_time  TYPE string,
        gate           TYPE string,
        seat           TYPE string,
        cabin_class    TYPE string,
      END OF ty_pass.

    "! Data for the boarding pass. Without a booking ID the first booking of the travel is used.
    CLASS-METHODS pass_data
      IMPORTING
        iv_travel_id   TYPE /dmo/travel-travel_id
        iv_booking_id  TYPE /dmo/booking-booking_id OPTIONAL
      RETURNING
        VALUE(rs_pass) TYPE ty_pass
      RAISING
        zcx_abappdf.

    "! Renders form ZPDF_BOARDING_PASS for the booking.
    CLASS-METHODS print
      IMPORTING
        iv_travel_id  TYPE /dmo/travel-travel_id
        iv_booking_id TYPE /dmo/booking-booking_id OPTIONAL
      RETURNING
        VALUE(rv_pdf) TYPE xstring
      RAISING
        zcx_abappdf.

  PRIVATE SECTION.
    CLASS-METHODS hhmm
      IMPORTING
        iv_seconds     TYPE i
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS date_text
      IMPORTING
        iv_date        TYPE d
      RETURNING
        VALUE(rv_text) TYPE string.
ENDCLASS.



CLASS zcl_abappdf_boarding IMPLEMENTATION.

  METHOD pass_data.
    DATA ls_book TYPE /dmo/booking.
    DATA lv_seconds TYPE i.

    IF iv_booking_id IS INITIAL.
      SELECT * FROM /dmo/booking
        WHERE travel_id = @iv_travel_id
        ORDER BY booking_id
        INTO @ls_book
        UP TO 1 ROWS.
      ENDSELECT.
    ELSE.
      SELECT SINGLE * FROM /dmo/booking
        WHERE travel_id = @iv_travel_id
          AND booking_id = @iv_booking_id
        INTO @ls_book.
    ENDIF.
    IF ls_book IS INITIAL.
      RAISE EXCEPTION TYPE zcx_abappdf
        EXPORTING textid = zcx_abappdf=>travel_missing.
    ENDIF.

    SELECT SINGLE first_name, last_name FROM /dmo/customer
      WHERE customer_id = @ls_book-customer_id
      INTO @DATA(ls_customer).
    SELECT SINGLE name FROM /dmo/carrier
      WHERE carrier_id = @ls_book-carrier_id
      INTO @DATA(lv_carrier_name).
    SELECT SINGLE airport_from_id, airport_to_id, departure_time, arrival_time, distance, distance_unit
      FROM /dmo/connection
      WHERE carrier_id = @ls_book-carrier_id
        AND connection_id = @ls_book-connection_id
      INTO @DATA(ls_connection).
    SELECT SINGLE city FROM /dmo/airport
      WHERE airport_id = @ls_connection-airport_from_id
      INTO @DATA(lv_from_city).
    SELECT SINGLE city FROM /dmo/airport
      WHERE airport_id = @ls_connection-airport_to_id
      INTO @DATA(lv_to_city).

    rs_pass-travel_id = |{ CONV i( ls_book-travel_id ) }|.
    rs_pass-booking_ref = |{ CONV i( ls_book-travel_id ) }-{ ls_book-booking_id }|.
    rs_pass-passenger_name = |{ ls_customer-first_name } { ls_customer-last_name }|.
    rs_pass-carrier_id = |{ ls_book-carrier_id }|.
    rs_pass-carrier_name = |{ lv_carrier_name }|.
    rs_pass-connection_id = |{ ls_book-connection_id }|.
    rs_pass-from_airport = |{ ls_connection-airport_from_id }|.
    rs_pass-from_city = |{ lv_from_city }|.
    rs_pass-to_airport = |{ ls_connection-airport_to_id }|.
    rs_pass-to_city = |{ lv_to_city }|.
    rs_pass-flight_date = date_text( ls_book-flight_date ).
    lv_seconds = ls_connection-departure_time.
    rs_pass-departure_time = hhmm( lv_seconds ).
    "Boarding starts 40 minutes before departure.
    rs_pass-boarding_time = hhmm( lv_seconds - 2400 ).
    lv_seconds = ls_connection-arrival_time.
    rs_pass-arrival_time = hhmm( lv_seconds ).
    rs_pass-distance = |{ ls_connection-distance } { to_lower( ls_connection-distance_unit ) }|.

    "Gate and seat are demo values derived from the connection and the booking.
    DATA(lv_connection) = CONV i( ls_book-connection_id ).
    DATA(lv_booking) = CONV i( ls_book-booking_id ).
    DATA(lv_travel) = CONV i( ls_book-travel_id ).
    rs_pass-gate = |{ substring( val = `ABCD` off = lv_connection MOD 4 len = 1 ) }{ lv_connection MOD 40 + 10 }|.
    rs_pass-seat = |{ lv_travel MOD 28 + 3 }{ substring( val = `ABCDEF` off = lv_booking MOD 6 len = 1 ) }|.
    rs_pass-cabin_class = `Economy`.

    CONDENSE: rs_pass-travel_id, rs_pass-booking_ref, rs_pass-passenger_name, rs_pass-carrier_name,
              rs_pass-from_city, rs_pass-to_city, rs_pass-distance.
  ENDMETHOD.


  METHOD print.
    rv_pdf = zcl_abappdf_api=>render_pdf(
      iv_form_id = c_form_id
      is_data    = pass_data( iv_travel_id  = iv_travel_id
                              iv_booking_id = iv_booking_id ) ).
  ENDMETHOD.


  METHOD hhmm.
    DATA lv_seconds TYPE i.
    lv_seconds = iv_seconds MOD 86400.
    rv_text = |{ lv_seconds DIV 3600 WIDTH = 2 ALIGN = RIGHT PAD = '0' }:| &&
              |{ lv_seconds MOD 3600 DIV 60 WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
  ENDMETHOD.


  METHOD date_text.
    CONSTANTS lc_months TYPE string VALUE `JanFebMarAprMayJunJulAugSepOctNovDec`.
    DATA lv_month TYPE i.
    DATA lv_day TYPE i.
    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    lv_month = iv_date+4(2).
    lv_day = iv_date+6(2).
    rv_text = |{ lv_day } { substring( val = lc_months off = ( lv_month - 1 ) * 3 len = 3 ) } { iv_date(4) }|.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    "Run with F9: prints the boarding pass for the first booking and shows its data.
    DATA ls_booking TYPE /dmo/booking.
    SELECT * FROM /dmo/booking
      ORDER BY travel_id, booking_id
      INTO @ls_booking
      UP TO 1 ROWS.
    ENDSELECT.
    IF ls_booking IS INITIAL.
      out->write( `No bookings in /DMO/BOOKING. Generate the flight model data first.` ).
      RETURN.
    ENDIF.
    TRY.
        DATA(ls_pass) = pass_data( iv_travel_id  = ls_booking-travel_id
                                   iv_booking_id = ls_booking-booking_id ).
        out->write( ls_pass ).
        DATA(lv_pdf) = print( iv_travel_id  = ls_booking-travel_id
                              iv_booking_id = ls_booking-booking_id ).
        out->write( |Boarding pass { ls_pass-booking_ref }: { xstrlen( lv_pdf ) } bytes| ).
      CATCH zcx_abappdf INTO DATA(lx_error).
        out->write( lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
