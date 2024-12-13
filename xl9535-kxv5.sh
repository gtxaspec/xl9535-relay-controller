#!/bin/bash

# Default I2C device address
I2C_ADDR=0x20
I2C_BUS=3

# Helper function to print usage
usage() {
	echo "XL9535-KxV5 Relay Board - I2C Controller"
	echo "Usage: $0 [-a <i2c_address>] [-b <i2c_bus>] <command> [relay_number]"
	echo "Commands:"
	echo "  all_on       Turn all relays on"
	echo "  all_off      Turn all relays off"
	echo "  toggle <x>   Toggle relay x"
	echo "  on <x>       Turn on relay x"
	echo "  off <x>      Turn off relay x"
	echo "Options:"
	echo "  -a <i2c_address> Specify the I2C device address (default: 0x20)"
	echo "  -b <i2c_bus>     Specify the I2C bus (default: 3)"
	echo "Examples:"
	echo "  # Turn all relays on using default address and bus"
	echo "  $0 all_on"
	echo "  "
	echo "  # Turn all relays off on I2C address 0x21 and bus 1"
	echo "  $0 -a 0x21 -b 1 all_off"
	echo "  "
	echo "  # Toggle relay 3 (A3)"
	echo "  $0 toggle 3"
	echo "  "
	echo "  # Turn on relay 9 (B1)"
	echo "  $0 on 9"
	echo "  "
	echo "  # Turn off relay 0 (A0)"
	echo "  $0 off 0"
	exit 1
}

# Parse options
while getopts "a:b:" opt; do
	case $opt in
		a) I2C_ADDR=$OPTARG ;;
		b) I2C_BUS=$OPTARG ;;
		*) usage ;;
	esac
done
shift $((OPTIND - 1))

# Validate command and arguments
if [ $# -lt 1 ]; then
	usage
fi

COMMAND=$1
RELAY=${2:-}

# Registers
DIRECTION_REG_A=0x06
DIRECTION_REG_B=0x07
OUTPUT_REG_A=0x02
OUTPUT_REG_B=0x03

# Initialize relays (set all GPIO as output)
i2cset -y $I2C_BUS $I2C_ADDR $DIRECTION_REG_A 0x00
i2cset -y $I2C_BUS $I2C_ADDR $DIRECTION_REG_B 0x00

# Helper function to read the current state of relays
read_state() {
	local reg=$1
	i2cget -y $I2C_BUS $I2C_ADDR $reg
}

# Helper function to write a new state to relays
write_state() {
	local reg=$1
	local value=$2
	i2cset -y $I2C_BUS $I2C_ADDR $reg $value
}

# Process commands
case $COMMAND in
	all_on)
		write_state $OUTPUT_REG_A 0xFF
		write_state $OUTPUT_REG_B 0xFF
		;;
	all_off)
		write_state $OUTPUT_REG_A 0x00
		write_state $OUTPUT_REG_B 0x00
		;;
	toggle)
		if [[ -z $RELAY ]]; then
			echo "Error: Relay number required for toggle"
			usage
		fi
		if [ $RELAY -lt 8 ]; then
			current=$(read_state $OUTPUT_REG_A)
			new=$((current ^ (1 << RELAY)))
			write_state $OUTPUT_REG_A $new
		else
			RELAY=$((RELAY - 8))
			current=$(read_state $OUTPUT_REG_B)
			new=$((current ^ (1 << RELAY)))
			write_state $OUTPUT_REG_B $new
		fi
		;;
	on)
		if [[ -z $RELAY ]]; then
			echo "Error: Relay number required for on"
			usage
		fi
		if [ $RELAY -lt 8 ]; then
			current=$(read_state $OUTPUT_REG_A)
			new=$((current | (1 << RELAY)))
			write_state $OUTPUT_REG_A $new
		else
			RELAY=$((RELAY - 8))
			current=$(read_state $OUTPUT_REG_B)
			new=$((current | (1 << RELAY)))
			write_state $OUTPUT_REG_B $new
		fi
		;;
	off)
		if [[ -z $RELAY ]]; then
			echo "Error: Relay number required for off"
			usage
		fi
		if [ $RELAY -lt 8 ]; then
			current=$(read_state $OUTPUT_REG_A)
			new=$((current & ~(1 << RELAY)))
			write_state $OUTPUT_REG_A $new
		else
			RELAY=$((RELAY - 8))
			current=$(read_state $OUTPUT_REG_B)
			new=$((current & ~(1 << RELAY)))
			write_state $OUTPUT_REG_B $new
		fi
		;;
	*)
		echo "Error: Unknown command '$COMMAND'"
		usage
		;;
esac
