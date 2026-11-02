# Mailbox day charts

Merge the mailbox schema and app support before Pi Keeper enables the new fields.
This PR does not deploy the Worker or change the Pi.

On `history` pushes only, `machine` may include `temperatureHistory: [{t, c}]`,
`memoryHistory: [{t, used}]`, and `diskHistory: [{t, used}]`. Each optional array
has 0–24 points. `t` is a nonnegative integer Unix timestamp in seconds, `c` is a
finite number in Celsius, and `used` is an integer percentage from 0 through 100.
Unknown keys and these fields on `live` are rejected. Missing arrays preserve the
old contract; empty arrays mean unavailable data, never zero.

CPU history accepts up to 288 points, including today's five-minute spacing and
Pi Keeper's planned 96 fifteen-minute points. The push cap remains 16,384 bytes.
The app averages available points into hours and shows each available series
independently. It omits missing hours and series rather than filling in zeros.
