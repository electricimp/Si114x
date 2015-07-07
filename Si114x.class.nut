class Si1145 {

    static version = [1,0,0];

    // i2c Registers
    static REG_PART_ID      = 0x00;

    static REG_INT_CFG      = 0x03;
    static REG_IRQ_ENABLE   = 0x04;
    static REG_HW_KEY       = 0x07;
    static REG_MEAS_RATE0   = 0x08;
    static REG_MEAS_RATE1   = 0x09;
    static REG_PS_RATE      = 0x0A;
    static REG_PS_LED21     = 0x0F;
    static REG_PS_LED3      = 0x10;
    static REG_UCOEF0       = 0x13;
    static REG_UCOEF1       = 0x14;
    static REG_UCOEF2       = 0x15;
    static REG_UCOEF3       = 0x16;
    static REG_PARAM_WR     = 0x17;
    static REG_COMMAND      = 0x18;
    static REG_RESPONSE     = 0x20;
    static REG_IRQ_STATUS   = 0x21;
    static REG_ALS_VIS_DATA0= 0x22;
    static REG_ALS_VIS_DATA1= 0x23;
    static REG_ALS_IR_DATA0 = 0x24;
    static REG_ALS_IR_DATA1 = 0x25;
    static REG_PS1_DATA0    = 0x26;
    static REG_PS1_DATA1    = 0x27;
    static REG_PS2_DATA0    = 0x28;
    static REG_PS2_DATA1    = 0x29;
    static REG_PS3_DATA0    = 0x2A;
    static REG_PS3_DATA1    = 0x2B;
    static REG_AUX_DATA0    = 0x2C; // REG_UVINDEX_DATA0
    static REG_AUX_DATA1    = 0x2D; // REG_UVINDEX_DATA1
    static REG_PARAM_RD     = 0x2E;
    static REG_CHIP_STAT    = 0x30;

    // Command Register
    static CMD_PARAM_QUERY  = 0x80;
    static CMD_PARAM_SET    = 0xA0;
    static CMD_NOP          = 0x00;
    static CMD_RESET        = 0x01;
    static CMD_BUSADDR      = 0x02;
    static CMD_PS_FORCE     = 0x05;
    static CMD_GET_CAL      = 0x12;
    static CMD_ALS_FORCE    = 0x06;
    static CMD_PSALS_FORCE  = 0x07;
    static CMD_PS_PAUSE     = 0x09;
    static CMD_ALS_PAUSE    = 0x0A;
    static CMD_PSALS_PAUSE  = 0x0B;
    static CMD_PS_AUTO      = 0x0D;
    static CMD_ALS_AUTO     = 0x0E;
    static CMD_PSALS_AUTO   = 0x0F;

    // Parameter RAM Addresses
    static PARAM_CH_LIST    = 0x01;

    // Channel list masks
    static CHLIST_UV        = 0x80; // 10000000
    static CHLIST_AUX       = 0x40; // 01000000
    static CHLIST_ALS_IR    = 0x20; // 00100000
    static CHLIST_ALS_VIS   = 0x10; // 00010000
    static CHLIST_PS3       = 0x04; // 00000100
    static CHLIST_PS2       = 0x02; // 00000010
    static CHLIST_PS1       = 0x01; // 00000001

    // Data Ready Channel Masks
    static DRDY_ALS         = 0x01; // 00000001
    static DRDY_PS1         = 0x04; // 00000100

    _i2c    = null;
    _addr   = null;

    _measRate = null;

    // Parameters:
    // i2c      A preconfigured I2C bus
    // addr     The base address of the SI1145 device
    constructor(i2c, addr=0xC0) {
        _i2c    = i2c;
        _addr   = addr;

        // Make sure we're talking to the right device
        if (getPartID() != 0x45) return null;

        // Initialize the device
        init();
    }

    function init() {
        // Send Hardware Key
        _writeReg(REG_HW_KEY, 0x17);
    }

    // Enables ALS (visible light, ir light, uv index) sensing
    function enableALS(state) {
        // Get the current channel list
        local chList = readParam(PARAM_CH_LIST);

        if (state) {
            // Set the UV Index coefficents
            _writeReg(REG_UCOEF0, 0x29);
            _writeReg(REG_UCOEF1, 0x89);
            _writeReg(REG_UCOEF2, 0x02);
            _writeReg(REG_UCOEF3, 0x00);

            // Write the channel list
            writeParam(PARAM_CH_LIST, chList | CHLIST_ALS_VIS | CHLIST_ALS_IR | CHLIST_UV);
        } else {
            // Clear the UV Index coefficents
            _writeReg(REG_UCOEF0, 0x00);
            _writeReg(REG_UCOEF1, 0x00);
            _writeReg(REG_UCOEF2, 0x00);
            _writeReg(REG_UCOEF3, 0x00);

            // Write the channel list
            writeParam(PARAM_CH_LIST, chList & ~CHLIST_ALS_VIS & ~CHLIST_ALS_IR & ~CHLIST_UV);
        }
    }

    // Enables proximity sensing (ps1)
    function enableProximity(state) {
        // Get the channel list
        local chList = readParam(PARAM_CH_LIST);

        if (state) {
            // Add PS1 to channel list
            writeParam(PARAM_CH_LIST, chList | CHLIST_PS1);

            // 0x08 = 220A (typical) / 450A (max)
            _writeReg(REG_PS_LED21, 0x08);
        } else {
            // Remove PS1 from the channel list
            writeParam(PARAM_CH_LIST, chList & ~CHLIST_PS1);

            // 0x00 = "No Current"
            _writeReg(REG_PS_LED21, 0x00);
        }
    }

    // Gets last visible light, ir light, and uv index
    function getALS(cb) {
        // Read the 3 ALS values
        local ir = _read16(REG_ALS_IR_DATA1, REG_ALS_VIS_DATA0);
        local uv = _read16(REG_AUX_DATA1, REG_AUX_DATA0) / 100.0;
        local visible = _read16(REG_ALS_VIS_DATA1, REG_ALS_VIS_DATA0);

        // Invoke the callback
        imp.wakeup(0, function() { cb({ "ir": ir, "uv": uv, "visible": visible }); });
    }

    // Gets last proximity (ps1)
    function getProximity(cb) {
        // Read the proximity value
        local proximity = _read16(REG_PS1_DATA1, REG_PS1_DATA0);

        // Invoke the callback
        imp.wakeup(0, function() { cb({ "proximity": proximity }); });
    }

    // Forces a proximity read (if datarate == 0)
    function forceReadProximity(cb) {
        // Send the force PS command
        _writeReg(REG_COMMAND, CMD_PS_FORCE);

        // Copy of 'this' to use in callback without having to bindenv
        local __si1145 = this;
        // Invoke the callback after a short period of time
        imp.wakeup(0.05, function() {
            __si1145.getProximity(cb);
        });
    }

    // Forces an ALS read (for when datarate == 0)
    function forceReadALS(cb) {
        // Send the force ALS command
        _writeReg(REG_COMMAND, CMD_ALS_FORCE);

        // Copy of 'this' to use in callback without having to bindenv
        local __si1145 = this;

        // Invoke the callback after a short period of time
        imp.wakeup(0.05, function() {
            __si1145.getALS(cb);
        });
    }

    // Sets the MEAS Rate for ALS and PS in Hz
    function setDataRate(dataRate) {
        // 0 breaks math - so handle that case first
        if (dataRate == 0) {
            _writeReg(REG_MEAS_RATE1, 0x00);
            _writeReg(REG_MEAS_RATE0, 0x00);
            _measRate = 0;
            return 0;
        }

        // Convert Hz to 31.25ms
        local rate = (32000.0/dataRate).tointeger();
        // clamp it to allowed values
        if (rate < 0) rate = 0;
        if (rate > 65535) rate = 65535;

        // Grab the low and high bytes
        local lowB = rate & 0xff;
        local highB = (rate & 0xff00) >> 8;

        // Write the MEAS_RATE registers
        _writeReg(REG_MEAS_RATE1, highB);
        _writeReg(REG_MEAS_RATE0, lowB);

        // Set PSALS_AUTO flag for autonomous mode
        _writeReg(REG_COMMAND, CMD_PSALS_AUTO)

        // Convert to Hz and store MEAS Rate
        _measRate = 32000.0 / ((highB << 8) + lowB);

        // Return MEAS Rate in Hz
        return _measRate;

    }

    // Returns the current MEAS Rate in Hz
    function getDataRate() {
        // Read the current MEAS_RATE registers
        local rate = _read16(REG_MEAS_RATE1, REG_MEAS_RATE0)

        // Set our _rate variable
        _measRate = 1.0 / (rate * 0.00003125);

        // Convert MEAS Rate to Hz
        return _measRate;
    }

    // Configures the data ready interrupt generator
    function configureDataReadyInterrupt(state, channels = null) {
        // Read the current IRQ_ENABLE state and clear the flag we may be setting
        local irqEn = _readReg(REG_IRQ_ENABLE) & ~DRDY_ALS & ~DRDY_PS1;

        if (state) {
            if (channels == null) channels = DRDY_ALS | DRDY_PS1;

            // Enable int pin, and interrupt on desired channels
            _setRegBit(REG_INT_CFG, 0, 1);
            _writeReg(REG_IRQ_ENABLE, irqEn | channels);
        } else {

            // Disable int pin, and clear interrupt channels
            _setRegBit(REG_INT_CFG, 0, 0);
            _writeReg(REG_IRQ_ENABLE, irqEn);
        }
    }

    // returns and clears the interrupt register as a table
    function getInterruptTable() {
        // Read the IRQ_STATUS register
        local irqStatus = _readReg(REG_IRQ_STATUS);

        // Write register value back to clear register (as per datasheet)
        _writeReg(REG_IRQ_STATUS, irqStatus);

        // Return table with bits we care about
        return {
            "als":      irqStatus & DRDY_ALS ? true : false
            "ps1":      irqStatus & DRDY_PS1 ? true : false,
        };
    }

    // Returns the PartID (should be 0x45)
    function getPartID() {
        return _readReg(REG_PART_ID);
    }

    // Write a value to the Parameter RAM
    function writeParam(param, value) {
        _writeReg(REG_PARAM_WR, value);
        _writeReg(REG_COMMAND, param | CMD_PARAM_SET);

        return _readReg(REG_PARAM_RD);
    }

    // Read a value from the Parameter RAM
    function readParam(param) {
        _writeReg(REG_COMMAND, param | CMD_PARAM_QUERY);
        return _readReg(REG_PARAM_RD);
    }

    //-------------------- PRIVATE METHODS --------------------//

    function _readReg(reg) {
        local result = _i2c.read(_addr, reg.tochar(), 1);
        if (result == null) {
            throw "I2C read error: " + _i2c.readerror();
        }

        // Return the first byte
        return result[0];
    }

    function _writeReg(reg, val) {
        local result = _i2c.write(_addr, format("%c%c", reg, (val & 0xff)));
        if (result) {
            throw "I2C write error: " + result;
        }
        return result;
    }

    // Reads a 16-bit value from a high and low register
    function _read16(highReg, lowReg) {
        local highB = _readReg(highReg);
        local lowB = _readReg(lowReg);

        local result = (highB << 8) + lowB;
        return result;
    }

    function _setRegBit(reg, bit, state) {
        local val = _readReg(reg);
        if (state == 0) {
            val = val & ~(0x01 << bit);
        } else {
            val = val | (0x01 << bit);
        }
        return _writeReg(reg, val);
    }

    function _twosComp(value, mask) {
        value = ~(value & mask) + 1;
        return value & mask;
    }
}
