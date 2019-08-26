#!/usr/bin/env python
# coding: utf-8

# In[665]:


# create dictionary for all opcodes
valid_op_codes = {'ADD':"0000", 'ADDI':"0000",                   'SUB':"0001", 'SUBI':"0001",                   'MUL':"0010", 'MULI':"0010",                   'DIV':"0011", 'DIVI':"0011",                   'LOG':"0100",                   'RTR':"0101", 'RTL':"0101", 'RTRI':"0101", 'RTLI':"0101",                   'SRL':"0110", 'SLL':"0110", 'SRLI':"0110", 'SLLI':"0110",                   'SRA':"0111", 'SLA':"0111", 'SRAI':"0111", 'SLAI':"0111",                   'LD':"1000", 'ST':"1000",                   'JMP':"1001",                   'BNE':"1010", 'BNEZ':"1010",                   'IOW':"1011", 'IOR':"1011",                   'ICW':"1011", 'ICR':"1011",                   'ANDI':"1100", 'ORI':"1100", 'XORI':"1100", 'NOT':"1100",                   'CP':"1101"}

# create dictionary for all instruction selects
valid_inst_sel = {'ADDI':"01", 'SUBI':"01"}

# dictionary for different register names
register_translator = {'R0': "00000", 'R1': "00001", 'R2': "00010", 'R3': "00011", 'R4': "00100",                        'R5': "00101", 'R6': "00110", 'R7': "00111", 'R8': "01000", 'R9': "01001",                        'R10': "01010", 'R11': "01011", 'R12': "01100", 'R13': "01101", 'R14': "01110",                        'R15': "01111", 'R16': "10000", 'R17': "10001", 'R18': "10010", 'R19': "10011",                        'R20': "10100", 'R21': "10101", 'R22': "10110", 'R23': "10111", 'R24': "11000",                        'R25': "11001", 'R26': "11010", 'R27': "11011", 'R28': "11100", 'R29': "11101",                        'R30': "11110", 'R31': "11111"}
valid_inst_sels = {'ADD':"00", 'ADDI':"01",                   'SUB':"00", 'SUBI':"01",                   'MUL':"00", 'MULI':"01",                   'DIV':"00", 'DIVI':"01",                   'LOG':"00",                   'RTR':"01", 'RTL':"00", 'RTRI':"11", 'RTLI':"10",                   'SRL':"01", 'SLL':"00", 'SRLI':"11", 'SLLI':"10",                   'SRA':"01", 'SLA':"00", 'SRAI':"11", 'SLAI':"10",                   'LD':"1000", 'ST':"1000",                   'JMP':"1001",                   'BNE':"01", 'BNEZ':"00",                   'IOW':"01", 'IOR':"00",                   'ICW':"11", 'ICR':"10",                   'ANDI':"00", 'ORI':"01", 'XORI':"10", 'NOT':"11",                   'CP':"00"}

# initialize array for error stack
errors = []


# In[666]:


def valid_op_code_found_in(line, label_found):
    word = line.split()[label_found]
      
    if word in valid_op_codes:
        # determine opcode
        return valid_op_codes[word]
    else:
        return None

def valid_label_found_in(line, index):
    if line.split()[0].split(':')[0] != "" and len(line.split()[0].split(':')) > 1:
        # initialize temporary label
        found_label = line.split()[0].split(':')[0]
        
        # check if it's already in 'labels'
        if found_label not in labels:
            
            # generate pure binary address
            binary = bin(index).split('b')[1]

            # generate needed padding
            padding = 11 - len(binary)

            # make complete address
            address = "{}{}".format(padding * "0", binary)

            # add address to label array
            labels[found_label] = address
            
        return 1
    else:
        return 0


# In[667]:


def determine_reg2(line, label_found):

    # determine temp and binary reg2
    if len(line.split()) > 2 and "(" not in line.split()[label_found + 2]:
        print("Determining reg2 value, line = {}".format(line))
        # grab raw r2 value
        r2 = line.split()[label_found + 2].split(',')[0]

        # enter this line for most arithmetic instructions, if it's a valid r2 value
        if ")" not in line.split()[label_found + 2] and r2 in register_translator:
            return register_translator[r2]
            print("Reg2 element is a register reference")

        # enter this line for loads and stores without a register offset
        elif ")" not in line.split()[label_found + 2]:
            print("Could not find valid reg2 in line")
            return None
        else:
            print("Error: Illegal parenthesis on line {}".format(index))
            errors.append("Error: Illegal parenthesis on line {}".format(index))
            return None

    elif len(line.split()) > 2 and "(" and ")" in line.split()[label_found + 2] and         line.split()[label_found + 2].split("(")[1].split(")")[0] in register_translator:

        print("Parenthesis found in reg2 element")

        r2 = line.split()[label_found + 2].split("(")[1].split(")")[0] 
        return register_translator[r2]
    
    else:
        print("Warning: Unknown reg2 field on line {}".format(index))
        return None

def determine_address(line, label_found):
    hex_addr = line.split()[label_found + 2].split("(")[0].split('x')[1]

    if int(hex_addr, 16) <= 0x07FF:
        DM_address = ((16 - len(bin(int(hex_addr, 16)).split('b')[1])) * "0") +         bin(int(hex_addr, 16)).split('b')[1]
        
        print("Reg2 is a hex number, binary address = {}".format(DM_address))
        return DM_address
    
    else:
        print("Error: Out of range address at line {}".format(index))
        errors.append("Error: Out of range address at line {}".format(index))
        return None

def determine_immed_val(line, label_found):
    hex_val = line.split()[label_found + 2].split("(")[0].split('x')[1]
    if int(hex_val, 16) <= 0x001F:
        immediate_value = ((5 - len(bin(int(hex_val, 16)).split('b')[1])) * "0") +         bin(int(hex_val, 16)).split('b')[1]
        
        print("Reg2 is a hex number, immediate value = {}".format(immediate_value))
        return immediate_value
    
    else:
        print("Error: Out of range immediate value at line {}".format(index))
        errors.append("Error: Out of range immediate value at line {}".format(index))
        return None


# In[668]:


#create empty dictionary for all label addresses
labels = {}

#create empty array of arrays representing entire program
# | opcode | reg1 | reg2 | inst_sel |
# | optional address |

program = []

# parameters to build each line in 'program' - these will all be binary values
opcode = ""
reg1 = ""
reg2 = ""
inst_sel = ""

# program counter to count total number of program lines
total_lines = 0

# open assembly program - this function automatically closes file
with open("test.asm", "r") as reader:
    lines = reader.readlines()

for index, line in enumerate(lines):
    print("Structuring code at line {}".format(index))
    
    # let's opcode function know whether there's a valid label so it can offset line entries
    label_found = 0

    # assign temporary array with program line elements
    temp_line = []

    # array to store next address for loads, stores, and branches
    address = []
    
    # array to store temporary DM addresses
    DM_address = []

    # first, check for a valid label (valid = first word in line, followed by a colon)
    if valid_label_found_in(line, total_lines):
        label_found = 1
        print("Found valid label in line {}".format(index))
    else:
        label_found = 0
        print("No valid label in line {}".format(index))

    # next, check for valid op code in line    
    if valid_op_code_found_in(line, label_found) is not None:

        # grab the actual opcode
        opcode = valid_op_code_found_in(line, label_found)
        
        if opcode is not valid_op_codes['JMP']:
            print("Opcode at line {} = {}".format(index, opcode))
            # determine temp and binary reg1
            r1 = line.split()[label_found + 1].split(',')[0]
            reg1 = register_translator[r1]

        if line.split()[label_found] == 'BNE':

            reg2 = determine_reg2(line, label_found)
            
            temp_line = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + valid_op_codes['BNE'] + reg1 + reg2 + "01" + ";\n"
            total_lines += 1
            
            if line.split()[label_found + 3] in labels:
                print("Found BNE label at line {}".format(index))
                address = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + "00000" + labels[line.split()[label_found + 3]] + ";\n"
            else:
                print("Did not find BNE label at line {}".format(index))
                address.append((11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + "00000")
                address.append(line.split()[label_found + 3])
                address.append(";\n")
                
            print("Binary at line {} = {}".format(index, temp_line))
            total_lines += 1
            
        elif line.split()[label_found] == 'BNEZ':
            temp_line = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + valid_op_codes['BNEZ'] + reg1 + "00000" + "00" + ";\n"
            total_lines += 1
            
            if line.split()[label_found + 1] in labels:
                print("Found BNEZ label at line {}".format(index))
                address.append((11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + "00000" + labels[line.split()[label_found + 2]] + ";\n")
            else:
                print("Did not find BNEZ label at line {}".format(index))
                address.append((11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + "00000")
                address.append(line.split()[label_found + 2])
                address.append(";\n")
                
            print("Binary at line {} = {}".format(index, temp_line))
            total_lines += 1
            
        elif line.split()[label_found] == 'LD':
            
            reg2 = determine_reg2(line, label_found)
            
            if reg2 is None:
                reg2 = "00000"
                inst_sel = "01"
            else:
                inst_sel = "00"
            
            temp_line = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + valid_op_codes['LD'] + reg1 + reg2 + inst_sel + ";\n"
            
            total_lines += 1
            
            address = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + determine_address(line, label_found) + ";\n"
            
            print("Binary at line {} = {}".format(index, temp_line))
            total_lines += 1
            
        elif line.split()[label_found] == 'ST':
            
            reg2 = determine_reg2(line, label_found)
            
            if reg2 is None:
                reg2 = "00000"
                inst_sel = "11"
            else:
                inst_sel = "10"
                
            temp_line = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + valid_op_codes['ST'] + reg1 + reg2 + inst_sel + ";\n"
            total_lines += 1
            
            address = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + determine_address(line, label_found) + ";\n"
            
            print("Binary at line {} = {}".format(index, temp_line))
            total_lines += 1
            
        elif line.split()[label_found] == 'JMP':

            # if the jump address is not in "labels", put placeholder
            if line.split()[label_found + 1] in labels:
                print("Found jump address for line {}".format(index))
                temp_line = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + valid_op_codes['JMP'] + labels[line.split()[label_found + 1]] + "0" + ";\n"
            else:
                print("Could not find label for line {}".format(index))
                temp_line.append((11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + valid_op_codes['JMP'])
                temp_line.append(line.split()[label_found + 1])
                temp_line.append("0")
                temp_line.append(";\n")
                
            print("Binary at line {} = {}".format(index, temp_line))
            total_lines += 1
            
        else:
            # apply to all other instructions
            
            inst_sel = valid_inst_sels[line.split()[label_found]]
            
            if determine_reg2(line, label_found) is not None:
                
                reg2 = determine_reg2(line, label_found)
                temp_line = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + opcode + reg1 + reg2 + inst_sel + ";\n"
                print("Binary at line {} = {}".format(index, temp_line))
                
            elif opcode is valid_op_codes['IOW'] or opcode is valid_op_codes['IOR']                 or opcode is valid_op_codes['ICW'] or opcode is valid_op_codes['ICR']:
                
                temp_line = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + opcode + reg1 + "00000" + inst_sel + ";\n"
                print("Binary at line {} = {}".format(index, temp_line))
                
            else:
                # must have an immediate value here, need to range check and convert to binary
                print("Determining immediate value at line {}".format(index))
                
                if determine_immed_val(line, label_found) is not None:
                    reg2 = determine_immed_val(line, label_found)
                    temp_line = (11 - len(bin(total_lines).split('b')[1])) * "0" + bin(total_lines).split('b')[1]                             + " : " + opcode + reg1 + reg2 + inst_sel + ";\n"
                    print("Binary at line {} = {}".format(index, temp_line))
                
            total_lines += 1
            
        # now, append both temp_line and address to "program" as applicable
        program.append(temp_line)

        if len(address) > 0:
            print("Writing address to program from line {}".format(index))
            program.append(address)

    else:
        print("Error: Invalid opcode found at line {}".format(index))
        errors.append("Error: Invalid opcode found at line {}".format(index))
        break

if len(errors) == 0:
    with open("PM.mif", "w") as writer:
        for index, line in enumerate(program):
            print("Program line = {}".format(line))
            # first confirm there are no unknown label fields
            if len(line) == 32:
                writer.write(line)
            # otherwise, write in those fields and write to program memory
            else:
                print(len(line))
                # since all addresses are always second label in program line, just identify that address
                if line[1] in labels and len(line) == 3:
                    # here's a BNE(Z) address
                    writer.write(line[0] + labels[line[1]] + line[2])

                elif line[1] in labels and len(line) == 4:
                    # here's a jump and associated address
                    writer.write(line[0] + labels[line[1]] + line[2] + line[3])

                else:
                    print("Error: Unknown label found during assembly, near line {}".format(index))
                    writer.close()
                    break    
else:
    for error in errors:
        print(error)

