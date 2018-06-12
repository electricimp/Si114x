# Si1145/46/47 #

The [Si114x](https://www.adafruit.com/datasheets/Si1145-46-47.pdf) is an I&sup2;c proximity, UV, and ambient light sensor. The Si114x library can be used with the Si1145, Si1146, and Si1147.

The Si114x interfaces over I&sup2;C, and works best with the clock rate set at `CLOCK_SPEED_100_KHZ` or `CLOCK_SPEED_400_KHZ`.If lower clockrates are used, you may need to add an `imp.sleep` at the beginning of your *forceRead** callbacks.

**To add this library to your project, add** `#require "Si114x.class.nut:1.0.0"` **to the top of your device code.**

You can view the library’s source code on [GitHub](https://github.com/electricimp/Si114x/tree/v1.0.0).

## Class Usage

### Constructor: Si114x(*i2c, [addr]*)

The class’ constructor takes one required parameter (a configured imp I&sup2;C bus) and an optional parameter (the I&sup2;C address of the sensor):

| Parameter     | Type         | Default | Description |
| ------------- | ------------ | ------- | ----------- |
| i2c           | hardware.i2c | N/A     | A pre-configured I&sup2;C bus |
| addr          | byte         | 0xC0   | The I&sup2;C address of the sensor |

```squirrel
#require "Si114x.class.nut:1.0.0"

i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

als <- Si114x(i2c);
```

## Class Methods

### enableALS(*state*)

Enables (*state* = `true`) or disable (*state* = `false`) the ambient light sensor. You must enable the ambient light sensor before calling *getALS* or *forceReadALS*

```squirrel
als.enableALS(true);
```

### enableProximity(*state*)

Enables (*state* = `true`) or disable (*state* = `false`) the proximity sensor. You must enable the proximity sensor before calling *getProximity* or *forceReadProximity*.

```squirrel
als.enableProximity(true);
```

### setDataRate(*dataRateHz*)

Sets the data rate for the ALS and proximity sensor (how often the device wakes up and takes a reading). Settings *dataRateHz* to 0 will disable autonomous mode (the device will **only** take readings by calling *forceReadALS* or *forceReadProximity*).

```squirrel
#require "Si114x.class.nut:1.0.0"

i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

als <- Si114x(i2c);
local dataRate = als.setDataRate(10);   // collect data 10 times per second
server.log("Data rate: " + dataRate);    // 10
```

**NOTE:** Not all data rates are available and the *setDataRate* method will return the actual data rate set

### getDataRate()

Returns the actual data rate set in Hz.

```squirrel
server.log("Data Rate: " + als.getDataRate() + " Hz");
```

### getALS(*callback*)

Collects the most recent data from the ALS sensor, and invokes the callback with a single parameter - a table containing the following keys:

```squirrel
{ "visible": int,     // The visible light (in lux)
  "ir": int,          // The IR light (in lux)
  "uv": float }       // The UV Index
```

**Note** The uv value is returned as a [UV index](http://www2.epa.gov/sunwise/uv-index-scale) between 0 and 11.

Before calling *getALS* you shoudl call *enableALS(true)* and *setDataRate(dataRateHz)* with a non-zero data rate.

```squirrel
#require "Si114x.class.nut:1.0.0"

i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

als <- Si114x(i2c);
als.enableALS(true);
als.setDataRate(2);    // 2Hz

// Poll the ALS data every second
function poll() {
  imp.wakeup(1, poll);
  als.getALS(function(data) {
    server.log("Visible: " + data.visible);
    server.log("IR Light: " + data.ir);
    server.log("UV Index: " + data.uv);
  });
}

poll();
```

### getProximity(*callback*)

Collects the most recent data from the proximity sensor, and invokes the callback with a single parameter - a table containing the following keys:

```squirrel
{ "proximity": int }      // The proximity value 0 (far) to 65535 (near)
```

Before calling *getProximity* you should call *enableProximity(true)* and *setDataRate(dataRateHz)* with a non-zero data rate.

```squirrel
#require "Si114x.class.nut:1.0.0"

i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

als <- Si114x(i2c);
als.enableProximity(true);
als.setDataRate(2);    // 2Hz

// Poll the ALS data every second
function poll() {
  imp.wakeup(1, poll);
  als.getProximity(function(data) {
    server.log("Proximity: " + data.proximity);
  });
}

poll();
```

### forceReadALS(*callback*)

The *forceReadALS* method forces the IC to update the ALS sensor information, and invoke the callback when complete. The callback is invoked with the same table as *getALSData*.

Before calling forceReadALS you shoudl call *enableALS(true)*.

```squirrel
#require "Si114x.class.nut:1.0.0"

i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

als <- Si114x(i2c);
als.enableALS(true);

// Get a 1-shot reading
als.forceReadALS(function(data) {
  server.log("Visible: " + data.visible);
  server.log("IR Light: " + data.ir);
  server.log("UV Index: " + data.uv);
});
```

### forceReadProximity(*callback*)
The *forceReadProximity* method forces the IC to update the proximity sensor information, and invoke the callback when complete. The callback is invoked with the same table as *getProximity*.

Before calling forceReadProximity you shoudl call *enableProximity(true)*.

```squirrel
#require "Si114x.class.nut:1.0.0"

i2c <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

als <- Si114x(i2c);
als.enableProximity(true);

// Get a 1-shot reading
als.forceReadProximity(function(data) {
  server.log("Proximity: " + data.proximity);
});
```

### configureDataReadyInterrupt(*state, [channels]*)
The Si114x can generate interrupts whenever new data is available from the ALS and/or proximity sensor. The configureDataReadyInterrupt allows you to enable (*state* = `true`) or disable (*state* = `false`) the data ready interrupt, as well as select what data should cause the interrupt. To specificy what channels to enable the data ready interrupts on, you can generate a bit field with either or both of `Si114x.DRDY_ALS` (for new ALS data) and `Si114x.DRDY_PROXIMITY`.

```squirrel
local i2c = hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

als <- Si114x(i2c, 0xC0);
als.setDataRate(2);   // 2 Hz

als.enableALS(true);
als.enableProximity(true);

als.configureDataReadyInterrupt(true, Si114x.DRDY_ALS | Si114x.DRDY_PROXIMITY);

alsInt <- hardware.pinD;
alsInt.configure(DIGITAL_IN, function() {
  if (alsInt.read() == 1) return;

  local state = als.getInterruptTable();
  if (state.als) {
    als.getALS(function(data) {
      server.log("Visible: " + data.visible);
      server.log("IR: " + data.ir);
      server.log("UV: " + data.uv);
    });
  }
  if (state.proximity) {
    als.getProximity(function(data) {
      server.log("Proximity: " + data.proximity);
    });
  }
});

```

### getInterruptTable()

The *getInterruptTable* method reads and clears the interrupt source register and returns a table with the following keys:

```sqirrel
{ "als": bool,           // True if new ALS data is available
  "proximity": bool }    // True if new proximity data is available
```

See *configureDataReadyInterrupts* for sample usage.

## License

The Si114x class is licensed under [MIT License](https://github.com/electricimp/si114x/tree/master/LICENSE).
