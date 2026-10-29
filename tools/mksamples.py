"""Write the sample databases shipped on the MouseDB disk (MOUSEDB1 text files)."""
import sys, os
KIND = {'Text': 1, 'Number': 2, 'Money': 3, 'Date': 4, 'Yes/No': 5}
def db(path, fields, records):
    out = ['MOUSEDB1', str(len(fields))]
    for (n, k, l, s) in fields:
        out.append('"%s",%d,%d,%d' % (n, KIND[k], l if k == 'Text' else {'Number': 10, 'Money': 12, 'Date': 10, 'Yes/No': 3}[k], s))
    out.append(str(len(records)))
    for r in records:
        assert len(r) == len(fields), r
        for (f, v) in zip(fields, r):
            assert '"' not in v and (f[1] != 'Text' or len(v) <= f[2]), (f, v)
            out.append('"%s"' % v)
    open(path, 'wb').write(('\r'.join(out) + '\r').encode('ascii'))

out = sys.argv[1]
os.makedirs(out, exist_ok=True)

# an address book (the people are made up)
db(out + '/ADDRESSES',
   [('Name', 'Text', 24, 1), ('Company', 'Text', 18, 0), ('Phone', 'Text', 14, 1),
    ('City', 'Text', 16, 1), ('State', 'Text', 2, 1), ('Birthday', 'Date', 0, 1),
    ('Email', 'Text', 30, 0), ('Card', 'Yes/No', 0, 1), ('Notes', 'Text', 40, 0)],
   [['Ada Brightwater', 'Clockwork Co.', '555-0101', 'Portland', 'OR', '1984-01-24', 'ada@example.com', 'Yes', 'Met at KansasFest'],
    ['Ben Okafor', '', '555-0142', 'Austin', 'TX', '1979-06-11', 'ben@example.com', 'Yes', ''],
    ['Carla Mendes', 'Pixel Works', '555-0177', 'Tucson', 'AZ', '1991-03-02', '', 'No', 'Collects IIgs cards'],
    ['Dmitri Volkov', '', '555-0119', 'Buffalo', 'NY', '', 'dmitri@example.com', 'Yes', ''],
    ['Elena Ruiz', 'Ruiz Repair', '555-0163', 'Denver', 'CO', '1988-11-30', 'elena@example.com', 'Yes', 'Recaps power supplies'],
    ['Frank Tilden', '', '555-0128', 'Omaha', 'NE', '1965-08-15', '', 'No', ''],
    ['Grace Liu', 'Byte Shop', '555-0150', 'San Jose', 'CA', '1977-04-16', 'grace@example.com', 'Yes', 'Sells disk drives'],
    ['Hank Morrow', '', '555-0136', 'Boise', 'ID', '', '', 'No', 'Has a spare IIc'],
    ['Ines Duarte', '', '555-0185', 'Miami', 'FL', '1995-12-03', 'ines@example.com', 'Yes', ''],
    ['Jonas Berg', 'Northern Retro', '555-0111', 'Duluth', 'MN', '1982-07-09', 'jonas@example.com', 'Yes', 'Swap meet in June'],
    ['Kim Palmer', '', '555-0190', 'Richmond', 'VA', '1970-02-28', '', 'No', ''],
    ['Leo Santos', '', '555-0158', 'Tampa', 'FL', '1986-09-21', 'leo@example.com', 'Yes', 'Mouse Calc fan']])

# a retro computer collection, like RetroInv's
db(out + '/COLLECTION',
   [('Item', 'Text', 28, 1), ('Maker', 'Text', 12, 1), ('Year', 'Number', 0, 1),
    ('Type', 'Text', 10, 1), ('Condition', 'Text', 9, 1), ('Location', 'Text', 12, 0),
    ('Value', 'Money', 0, 1), ('Bought', 'Date', 0, 0), ('Works', 'Yes/No', 0, 0),
    ('Notes', 'Text', 40, 0)],
   [['Apple IIe Enhanced', 'Apple', '1985', 'Computer', 'Excellent', 'Desk', '450.00', '2019-05-11', 'Yes', 'Platinum keyboard, 128K'],
    ['Extended 80-Column Card', 'Apple', '1983', 'Card', 'Excellent', 'In the IIe', '35.00', '2019-05-11', 'Yes', '64K'],
    ['Super Serial Card', 'Apple', '1981', 'Card', 'Good', 'In the IIe', '40.00', '', 'Yes', 'Slot 2'],
    ['AppleMouse II Card', 'Apple', '1984', 'Card', 'Good', 'In the IIe', '45.00', '2020-02-01', 'Yes', 'Slot 4, mouse in drawer'],
    ['Disk II Controller', 'Apple', '1978', 'Card', 'Good', 'In the IIe', '60.00', '', 'Yes', 'Slot 6'],
    ['Disk II Drive', 'Apple', '1978', 'Peripheral', 'Good', 'Desk', '125.50', '2018-10-20', 'Yes', 'Cleaned heads'],
    ['Apple IIGS ROM 3', 'Apple', '1989', 'Computer', 'Excellent', 'Den', '600.00', '2021-07-04', 'Yes', '4 MB'],
    ['AppleColor RGB Monitor', 'Apple', '1986', 'Peripheral', 'Good', 'Den', '150.00', '2021-07-04', 'Yes', ''],
    ['Apple 3.5 Drive', 'Apple', '1986', 'Peripheral', 'Fair', 'Den', '80.00', '', 'No', 'Slow eject'],
    ['Apple IIc', 'Apple', '1984', 'Computer', 'Good', 'Shelf 1', '275.00', '2017-03-18', 'Yes', 'With carrying case'],
    ['Oregon Trail', 'MECC', '1985', 'Software', 'For Parts', 'Box A', '20.00', '', 'No', 'Disk will not boot'],
    ['Kraft Joystick', 'Kraft', '1982', 'Accessory', 'Poor', 'Drawer', '5.00', '', 'Yes', 'Sticky button'],
    ['AppleWorks 3.0 Manual', 'Claris', '1989', 'Documents', 'Excellent', 'Shelf 2', '15.00', '2022-01-15', '', ''],
    ['ImageWriter II', 'Apple', '1985', 'Peripheral', 'Good', 'Closet', '90.00', '2016-09-09', 'Yes', 'New ribbon']])

# a software library
db(out + '/SOFTWARE',
   [('Title', 'Text', 24, 1), ('Publisher', 'Text', 16, 1), ('Year', 'Number', 0, 1),
    ('Genre', 'Text', 12, 1), ('Format', 'Text', 5, 1), ('Disks', 'Number', 0, 0),
    ('Paid', 'Money', 0, 1), ('Boxed', 'Yes/No', 0, 1), ('Manual', 'Yes/No', 0, 0)],
   [['Karateka', 'Broderbund', '1984', 'Action', '5.25', '1', '25.00', 'Yes', 'Yes'],
    ['Lode Runner', 'Broderbund', '1983', 'Puzzle', '5.25', '1', '30.00', 'No', 'Yes'],
    ['Choplifter', 'Broderbund', '1982', 'Action', '5.25', '1', '18.00', 'Yes', 'No'],
    ['Zork I', 'Infocom', '1980', 'Adventure', '5.25', '1', '45.50', 'Yes', 'Yes'],
    ['Ultima IV', 'Origin', '1985', 'Role-playing', '5.25', '4', '60.00', 'Yes', 'Yes'],
    ['The Oregon Trail', 'MECC', '1985', 'Education', '5.25', '2', '20.00', 'No', 'No'],
    ['AppleWorks 3.0', 'Claris', '1989', 'Office', '3.5', '2', '35.00', 'Yes', 'Yes'],
    ['Print Shop', 'Broderbund', '1984', 'Graphics', '5.25', '2', '22.00', 'No', 'Yes'],
    ['Mouse Calc', 'Version Soft', '1984', 'Office', '5.25', '2', '40.00', 'Yes', 'Yes'],
    ['Carmen Sandiego', 'Broderbund', '1985', 'Education', '5.25', '2', '15.00', 'No', 'No'],
    ['Wizardry', 'Sir-Tech', '1981', 'Role-playing', '5.25', '2', '55.00', 'Yes', 'Yes'],
    ['Prince of Persia', 'Broderbund', '1989', 'Action', '5.25', '2', '28.00', 'Yes', 'Yes'],
    ['Hard Hat Mack', 'Electronic Arts', '1983', 'Action', '5.25', '1', '12.00', 'No', 'No'],
    ['Copy II Plus', 'Central Point', '1987', 'Utility', '3.5', '1', '25.00', 'No', 'Yes'],
    ['ProDOS 8 2.4.3', 'John Brooks', '2023', 'Utility', '5.25', '1', '0.00', 'No', 'No']])
print('wrote ADDRESSES, COLLECTION, SOFTWARE')
