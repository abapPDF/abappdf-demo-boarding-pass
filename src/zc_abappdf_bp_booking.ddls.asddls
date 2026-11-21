@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ABAPpdf boarding pass demo'
@Metadata.allowExtensions: true
define root view entity ZC_ABAPPDF_BP_BOOKING
  as select from    /dmo/booking    as Booking
    left outer join /dmo/customer   as Customer
      on Customer.customer_id = Booking.customer_id
    left outer join /dmo/connection as Connection
      on  Connection.carrier_id    = Booking.carrier_id
      and Connection.connection_id = Booking.connection_id
{
  key Booking.travel_id,
  key Booking.booking_id,
      concat_with_space( Customer.first_name, Customer.last_name, 1 ) as passenger_name,
      Booking.carrier_id,
      Booking.connection_id,
      Connection.airport_from_id,
      Connection.airport_to_id,
      Booking.flight_date,
      concat(
        concat(
          concat( '/sap/bc/http/sap/zabappdf_bp_http?travel=', cast( Booking.travel_id as abap.char( 8 ) ) ),
          '&booking=' ),
        cast( Booking.booking_id as abap.char( 4 ) ) ) as boarding_url,
      cast( 'Boarding pass' as abap.char( 13 ) ) as boarding_label
}
