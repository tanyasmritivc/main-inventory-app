export type Audience = 'robotics' | 'workshops' | 'makers' | 'labs' | 'home';
export type PageKey = 'home' | 'solutions' | 'founders' | 'plans' | `sol:${Audience}`;
export interface DemoItem { n: string; q: number; loc: string; img?: string; low: number }
export interface Solution { t:string; d:string; h:string; p:string; win:string; blurb:string; prob:[string,string]; note?:[string,string,string]; uh?:[string,string]; items:DemoItem[]; sheet?:string[][]; asks:string[]; scene:{q:string[]; a:string[]; hit:string; add:[string,string,string]}; labels:string[]; card:[string,string]; uses:[string,string][]; cta:string }
export const FZ_ITEMS: DemoItem[] = [
  {
    "n": "M3 x 10mm screws",
    "q": 120,
    "loc": "Drawer 2, Robotics bench",
    "img": "p5",
    "low": 20
  },
  {
    "n": "M3 nuts",
    "q": 80,
    "loc": "Drawer 2, Robotics bench",
    "img": "p0",
    "low": 20
  },
  {
    "n": "M5 x 20 screws",
    "q": 25,
    "loc": "Fastener bin B",
    "img": "p6",
    "low": 10
  },
  {
    "n": "goBILDA 5203 motors",
    "q": 3,
    "loc": "Parts cabinet, shelf 1",
    "low": 4
  },
  {
    "n": "REV servo hubs",
    "q": 1,
    "loc": "Electronics tote",
    "low": 2
  },
  {
    "n": "USB-C cables",
    "q": 6,
    "loc": "Electronics tote",
    "low": 2
  },
  {
    "n": "8mm REX shaft, 300mm",
    "q": 4,
    "loc": "Long parts rack",
    "low": 2
  },
  {
    "n": "Spare battery packs",
    "q": 2,
    "loc": "Charging shelf",
    "low": 3
  }
];
export const FZ_SHEET: string[][] = [
  [
    "Part #",
    "Description",
    "Qty",
    "Location"
  ],
  [
    "PN-F91",
    "M3 washer",
    "150",
    "Drawer 2"
  ],
  [
    "PN-F111",
    "M5x20 screw",
    "25",
    "Fastener bin B"
  ],
  [
    "PN-F78",
    "M3x6mm set screw",
    "50",
    "Drawer 4"
  ],
  [
    "PN-F213",
    "Extension spring 1/4 in",
    "4",
    "Parts cabinet"
  ]
];
export const SOL: Record<Audience, Solution> = {
  "robotics": {
    "t": "Robotics teams",
    "d": "FTC and FRC parts, tools and electronics",
    "h": "Less time searching for parts. More time building robots.",
    "p": "FindEZ AI helps robotics teams bring their parts, tools, electronics, and supplies into searchable inventory. Import your existing records, capture items, and ask FindEZ what your team has.",
    "win": "Robotics Lab",
    "blurb": "Keep track of parts, tools, electronics, and supplies, so your team spends less time searching and more time building.",
    "prob": [
      "Tournament day is not the time to search every bin.",
      "Your team has parts, tools, spare components, and equipment spread across bins, drawers, and storage. Someone remembers seeing the part, but nobody remembers exactly where. FindEZ helps your team search what you've recorded instead of relying only on memory."
    ],
    "note": [
      "As a robotics mentor and FindEZ user, I know how much time teams can lose tracking down parts during tournament season. We built FindEZ to make our existing inventory easier to access: bring in the spreadsheet, capture parts, and ask what we have when we need it. The goal is simple. Less searching, more building.",
      "Tanya",
      "Founder of FindEZ AI and FTC robotics mentor"
    ],
    "items": [
      {
        "n": "M3 x 10mm screws",
        "q": 120,
        "loc": "Drawer 2, Robotics bench",
        "img": "p5",
        "low": 20
      },
      {
        "n": "M3 nuts",
        "q": 80,
        "loc": "Drawer 2, Robotics bench",
        "img": "p0",
        "low": 20
      },
      {
        "n": "M5 x 20 screws",
        "q": 25,
        "loc": "Fastener bin B",
        "img": "p6",
        "low": 10
      },
      {
        "n": "goBILDA 5203 motors",
        "q": 3,
        "loc": "Parts cabinet, shelf 1",
        "low": 4
      },
      {
        "n": "REV servo hubs",
        "q": 1,
        "loc": "Electronics tote",
        "low": 2
      },
      {
        "n": "USB-C cables",
        "q": 6,
        "loc": "Electronics tote",
        "low": 2
      },
      {
        "n": "8mm REX shaft, 300mm",
        "q": 4,
        "loc": "Long parts rack",
        "low": 2
      },
      {
        "n": "Spare battery packs",
        "q": 2,
        "loc": "Charging shelf",
        "low": 3
      }
    ],
    "asks": [
      "Where are the M3 screws?",
      "What is running low?",
      "Do we have any servo hubs?"
    ],
    "scene": {
      "q": [
        "Where are the M3 screws?",
        "Add 24 M4 screws to Drawer 3",
        "What is running low?"
      ],
      "a": [
        "<b>M3 x 10mm screws</b> are recorded in <b>Drawer 2</b>. You have 120.",
        "Drafted <b>M4 screws, 24, Drawer 3</b>. Saved after you approve.",
        "<b>3 items</b> are at or below the low level you set."
      ],
      "hit": "M3 x 10mm screws",
      "add": [
        "M4 screws",
        "Drawer 3",
        "24"
      ]
    },
    "labels": [
      "M3 screws · Drawer 2",
      "Servo hubs · Tote",
      "USB-C cables · Tote",
      "Motors · Cabinet",
      "Batteries · Charging",
      "REX shaft · Rack"
    ],
    "card": [
      "Do we have a spare servo hub?",
      "1 REV servo hub, in the Electronics tote."
    ],
    "uses": [
      [
        "Import the team spreadsheet",
        "Bring in the parts list you already keep. Your column names stay exactly as they are."
      ],
      [
        "Add parts as they arrive",
        "Describe them in a sentence or use photo capture, then review before anything is saved."
      ],
      [
        "Ask what the team has",
        "Check whether a part is in the recorded inventory, and use recorded locations to see where the team stored it."
      ]
    ],
    "cta": "Give your team a better way to find its parts."
  },
  "workshops": {
    "t": "Workshops & machine shops",
    "d": "Tooling, accessories and spare parts",
    "h": "Your inventory shouldn't depend on someone's memory.",
    "p": "From CNC machine accessories and 3D printer supplies to tooling, hardware, and replacement parts, FindEZ helps make the physical inventory you manage easier to record and search.",
    "win": "Main Shop",
    "blurb": "Make tools, accessories, spare parts, and equipment easier to keep track of.",
    "prob": [
      "The machine is only one part of the operation.",
      "A workshop manages more than machines. It manages tooling, accessories, consumables, spare parts, supplies, and the things needed to keep work moving. When that information lives across spreadsheets, shelves, and memory, finding a specific component takes time."
    ],
    "uh": [
      "Make the inventory around your equipment easier to find.",
      "Bring existing records into FindEZ, capture items, and ask questions about what you have recorded. Keep the information you need closer to the work."
    ],
    "items": [
      {
        "n": "ER32 collets",
        "q": 14,
        "loc": "CNC 1 tool cart",
        "low": 6
      },
      {
        "n": "1/4\" carbide end mills",
        "q": 8,
        "loc": "Tool crib, drawer A",
        "low": 4
      },
      {
        "n": "PLA filament, black",
        "q": 3,
        "loc": "3D printer shelf",
        "low": 4
      },
      {
        "n": "Waterjet garnet, 50 lb",
        "q": 5,
        "loc": "Back room",
        "low": 3
      },
      {
        "n": "Digital calipers",
        "q": 3,
        "loc": "Inspection bench",
        "low": 1
      },
      {
        "n": "Cutting fluid, 1 gal",
        "q": 1,
        "loc": "Fluids cabinet",
        "low": 2
      },
      {
        "n": "Face mill inserts",
        "q": 30,
        "loc": "CNC 2",
        "low": 10
      },
      {
        "n": "Drill bit sets",
        "q": 3,
        "loc": "Bench 1",
        "low": 1
      },
      {
        "n": "Coolant filters",
        "q": 2,
        "loc": "Back room",
        "low": 2
      }
    ],
    "sheet": [
      [
        "Tool ID",
        "Item",
        "Qty",
        "Station"
      ],
      [
        "T-104",
        "1/2\" end mill",
        "6",
        "Tool crib"
      ],
      [
        "T-220",
        "Face mill insert",
        "30",
        "CNC 2"
      ],
      [
        "C-011",
        "Coolant filter",
        "2",
        "Back room"
      ],
      [
        "M-050",
        "Drill bit set",
        "3",
        "Bench 1"
      ]
    ],
    "asks": [
      "Where are the ER32 collets?",
      "What needs restocking?",
      "How much PLA do we have?"
    ],
    "scene": {
      "q": [
        "Where are the ER32 collets?",
        "Add 2 boxes of M6 bolts to drawer B",
        "What needs restocking?"
      ],
      "a": [
        "<b>ER32 collets</b> are recorded on the <b>CNC 1 tool cart</b>. You have 14.",
        "Drafted <b>M6 bolts, 2 boxes, Drawer B</b>. Saved after you approve.",
        "<b>3 items</b> are at or below the low level you set."
      ],
      "hit": "ER32 collets",
      "add": [
        "M6 bolts",
        "Drawer B",
        "2"
      ]
    },
    "labels": [
      "End mills · Crib A",
      "Collets · CNC 1",
      "PLA · Shelf 3",
      "Garnet · Back room",
      "Calipers · Bench",
      "Inserts · CNC 2"
    ],
    "card": [
      "Where are the ER32 collets?",
      "14, on the CNC 1 tool cart."
    ],
    "uses": [
      [
        "Start from your sheet",
        "Import the tool list you already have. You don't have to rebuild it from scratch."
      ],
      [
        "Capture or describe",
        "Add tooling, accessories and spares by typing naturally or with photo capture."
      ],
      [
        "Ask before you stop work",
        "Check whether a component is recorded, and where it is kept, without leaving the machine."
      ]
    ],
    "cta": "Make your workshop inventory easier to search."
  },
  "makers": {
    "t": "Makers & makerspaces",
    "d": "Components, supplies and shared equipment",
    "h": "Shared tools. One place to find them.",
    "p": "Components, supplies, and shared equipment move between projects and people. FindEZ gives everyone the same answer to \"where is it recorded?\"",
    "win": "Makerspace",
    "blurb": "Keep components, supplies, and shared equipment easier to find.",
    "prob": [
      "Everyone borrows. Nobody remembers where it went back.",
      "Shared spaces collect bins of components, rolls of material, and tools that many hands use. When the only record is the person who last used it, a quick project turns into a search."
    ],
    "items": [
      {
        "n": "Digital multimeters",
        "q": 6,
        "loc": "Electronics wall",
        "low": 2
      },
      {
        "n": "Soldering irons",
        "q": 8,
        "loc": "Bench 3 drawer",
        "low": 3
      },
      {
        "n": "Arduino Uno boards",
        "q": 12,
        "loc": "Component bins, row C",
        "low": 5
      },
      {
        "n": "Acrylic sheets, 3mm",
        "q": 4,
        "loc": "Material rack",
        "low": 6
      },
      {
        "n": "Hot glue sticks",
        "q": 40,
        "loc": "Craft cart",
        "low": 15
      },
      {
        "n": "Oscilloscope",
        "q": 1,
        "loc": "Test bench",
        "low": 1
      },
      {
        "n": "Breadboards",
        "q": 18,
        "loc": "Component bins, row C",
        "low": 6
      },
      {
        "n": "3D printer nozzles",
        "q": 20,
        "loc": "Printer cart",
        "low": 5
      },
      {
        "n": "Safety glasses",
        "q": 9,
        "loc": "Entrance shelf",
        "low": 10
      }
    ],
    "sheet": [
      [
        "Asset",
        "Name",
        "Qty",
        "Room"
      ],
      [
        "EL-01",
        "Bench power supply",
        "3",
        "Test bench"
      ],
      [
        "EL-07",
        "Logic analyzer",
        "2",
        "Electronics wall"
      ],
      [
        "3D-12",
        "Nozzles 0.4mm",
        "20",
        "Printer cart"
      ],
      [
        "CR-03",
        "Glue gun",
        "5",
        "Craft cart"
      ]
    ],
    "asks": [
      "Where are the multimeters?",
      "What is running low?",
      "How many Arduino boards are there?"
    ],
    "scene": {
      "q": [
        "Where are the multimeters?",
        "Add 10 breadboards to row C",
        "What is running low?"
      ],
      "a": [
        "<b>Digital multimeters</b> are recorded on the <b>Electronics wall</b>. There are 6.",
        "Drafted <b>Breadboards, 10, Row C</b>. Saved after you approve.",
        "<b>3 items</b> are at or below the low level you set."
      ],
      "hit": "Digital multimeters",
      "add": [
        "Breadboards",
        "Row C",
        "10"
      ]
    },
    "labels": [
      "Multimeters · Wall",
      "Soldering irons · Bench 3",
      "Arduino · Row C",
      "Acrylic · Rack",
      "Nozzles · Printer cart",
      "Glasses · Entrance"
    ],
    "card": [
      "How many multimeters are there?",
      "6, on the Electronics wall."
    ],
    "uses": [
      [
        "One shared inventory",
        "Members and students search the same records."
      ],
      [
        "Know what is running low",
        "Set low levels for consumables and ask what needs restocking."
      ],
      [
        "Add as you go",
        "Snap a photo of a new bin or describe it in a sentence."
      ]
    ],
    "cta": "Make your shared space easier to search."
  },
  "labs": {
    "t": "Engineering labs",
    "d": "Instruments, sensors and consumables",
    "h": "Make shared inventory easier to record and search.",
    "p": "Instruments, test equipment, sensors, and consumables move between benches and projects. FindEZ helps your lab keep one searchable record of what you have and where it is kept.",
    "win": "Engineering Lab",
    "blurb": "Make shared inventory easier to record and search.",
    "prob": [
      "The probe was on the bench last week.",
      "Lab equipment is shared across courses, projects, and people. Asset lists go stale and consumables run out quietly. FindEZ helps your lab search what is recorded instead of asking around."
    ],
    "items": [
      {
        "n": "Oscilloscope probes",
        "q": 12,
        "loc": "Test bench 2",
        "low": 4
      },
      {
        "n": "Strain gauges",
        "q": 25,
        "loc": "Cabinet B, drawer 3",
        "low": 10
      },
      {
        "n": "Thermocouples, type K",
        "q": 6,
        "loc": "Cabinet B, drawer 1",
        "low": 8
      },
      {
        "n": "Function generators",
        "q": 3,
        "loc": "Instrument shelf",
        "low": 1
      },
      {
        "n": "Torque wrench",
        "q": 2,
        "loc": "Tool wall",
        "low": 0
      },
      {
        "n": "Load cells, 50 kg",
        "q": 1,
        "loc": "Test rig cart",
        "low": 1
      },
      {
        "n": "DAQ modules",
        "q": 4,
        "loc": "Instrument shelf",
        "low": 1
      },
      {
        "n": "Epoxy, 2 part",
        "q": 1,
        "loc": "Chemical cabinet",
        "low": 2
      },
      {
        "n": "Safety goggles",
        "q": 14,
        "loc": "Lab entrance",
        "low": 10
      }
    ],
    "sheet": [
      [
        "Asset tag",
        "Description",
        "Qty",
        "Room"
      ],
      [
        "EL-210",
        "Oscilloscope probe",
        "12",
        "Test bench 2"
      ],
      [
        "ME-044",
        "Torque wrench",
        "2",
        "Tool wall"
      ],
      [
        "ME-102",
        "Load cell 50 kg",
        "1",
        "Test rig cart"
      ],
      [
        "EL-305",
        "DAQ module",
        "4",
        "Instrument shelf"
      ]
    ],
    "asks": [
      "Where are the strain gauges?",
      "What is running low?",
      "How many oscilloscope probes are there?"
    ],
    "scene": {
      "q": [
        "Where are the strain gauges?",
        "Add 4 load cells to the test rig cart",
        "What is running low?"
      ],
      "a": [
        "<b>Strain gauges</b> are recorded in <b>Cabinet B, drawer 3</b>. There are 25.",
        "Drafted <b>Load cells, 4, Test rig cart</b>. Saved after you approve.",
        "<b>3 items</b> are at or below the low level you set."
      ],
      "hit": "Strain gauges",
      "add": [
        "Load cells",
        "Test rig cart",
        "4"
      ]
    },
    "labels": [
      "Probes · Bench 2",
      "Gauges · Cabinet B",
      "DAQ · Shelf",
      "Wrench · Tool wall",
      "Load cells · Rig cart",
      "Goggles · Entrance"
    ],
    "card": [
      "Where are the strain gauges?",
      "Cabinet B, drawer 3."
    ],
    "uses": [
      [
        "Start from the asset list",
        "Import the spreadsheet the lab already keeps."
      ],
      [
        "One record for shared equipment",
        "Students and staff search the same inventory instead of asking around."
      ],
      [
        "Know what needs reordering",
        "Set low levels for consumables and ask what is running low."
      ]
    ],
    "cta": "Make your lab inventory easier to search."
  },
  "home": {
    "t": "Everyday life",
    "d": "What you own and where you keep it",
    "h": "Your things. Finally, findable.",
    "p": "Remember what you own and where you keep it. Record things once, then ask FindEZ when you need them.",
    "win": "Home",
    "blurb": "Remember what you own and where you keep it.",
    "prob": [
      "You know you own it. You just can't find it.",
      "Chargers end up in drawers, tools move between the garage and the closet, and spare parts hide in boxes. Then you buy another one you already had."
    ],
    "items": [
      {
        "n": "Cordless drill",
        "q": 1,
        "loc": "Garage, bottom cabinet",
        "low": 0
      },
      {
        "n": "AA batteries",
        "q": 4,
        "loc": "Kitchen drawer",
        "low": 6
      },
      {
        "n": "Spare phone charger",
        "q": 1,
        "loc": "Hall closet, cable box",
        "low": 1
      },
      {
        "n": "LED light bulbs",
        "q": 4,
        "loc": "Hall closet, top shelf",
        "low": 2
      },
      {
        "n": "Holiday lights",
        "q": 3,
        "loc": "Attic, box 2",
        "low": 1
      },
      {
        "n": "Paper towels",
        "q": 2,
        "loc": "Pantry",
        "low": 3
      },
      {
        "n": "Tent, 4 person",
        "q": 1,
        "loc": "Garage",
        "low": 0
      },
      {
        "n": "Extension cords",
        "q": 2,
        "loc": "Garage",
        "low": 1
      },
      {
        "n": "Picture hooks",
        "q": 30,
        "loc": "Hall closet",
        "low": 5
      }
    ],
    "sheet": [
      [
        "Item",
        "Notes",
        "Qty",
        "Where"
      ],
      [
        "Tent",
        "4 person",
        "1",
        "Garage"
      ],
      [
        "Extension cords",
        "25 ft",
        "2",
        "Garage"
      ],
      [
        "Batteries AAA",
        "",
        "8",
        "Kitchen drawer"
      ],
      [
        "Picture hooks",
        "",
        "30",
        "Hall closet"
      ]
    ],
    "asks": [
      "Where did I put the drill?",
      "What am I running low on?",
      "Do I have spare light bulbs?"
    ],
    "scene": {
      "q": [
        "Where did I put the drill?",
        "Add a camping lantern to the garage",
        "What am I running low on?"
      ],
      "a": [
        "The <b>cordless drill</b> is recorded in <b>Garage, bottom cabinet</b>.",
        "Drafted <b>Camping lantern, 1, Garage</b>. Saved after you approve.",
        "<b>3 items</b> are at or below the low level you set."
      ],
      "hit": "Cordless drill",
      "add": [
        "Camping lantern",
        "Garage",
        "1"
      ]
    },
    "labels": [
      "Drill · Garage",
      "Batteries · Kitchen",
      "Charger · Hall closet",
      "Bulbs · Top shelf",
      "Lights · Attic",
      "Tent · Garage"
    ],
    "card": [
      "Where did I put the drill?",
      "Garage, bottom cabinet."
    ],
    "uses": [
      [
        "Know before you buy",
        "Check whether you already have it before buying a duplicate."
      ],
      [
        "Garage, closets, attic",
        "Record where things are kept, then just ask."
      ],
      [
        "Snap a box, add it all",
        "Capture a storage box with a photo and review what is found."
      ]
    ],
    "cta": "Get started with free Founders Access."
  }
};
export const ORDER: Audience[] = [
  "robotics",
  "workshops",
  "makers",
  "labs",
  "home"
];
export const ART: Record<Audience,string> = {
  "robotics": "a1",
  "workshops": "a2",
  "makers": "a3",
  "labs": "a5",
  "home": "a4"
};
export const FAQ: [string,string][] = [
  [
    "Is Founders Access really free?",
    "Yes. FindEZ AI is currently available through free Founders Access. Paid plans may be introduced in the future, and we will communicate any changes in advance."
  ],
  [
    "How does FindEZ know where my things are?",
    "FindEZ answers from what's recorded in your inventory. If you saved a location, it can tell you. It cannot locate things that were never added."
  ],
  [
    "Can I bring in my existing spreadsheet?",
    "Yes. Import your inventory spreadsheet and FindEZ keeps your column names exactly as they are."
  ],
  [
    "How accurate is photo capture?",
    "FindEZ suggests what it sees, most confident first, and shows you before anything is saved. Small parts can be hard to size from a photo, so you can review and edit every item."
  ],
  [
    "Can my team use it together?",
    "Yes. Invite your team so everyone searches and updates the same inventory."
  ],
  [
    "Where can I use FindEZ?",
    "On iPhone and on the web at findez.ai."
  ]
];
export const CMP: [string,string][] = [
  [
    "Manually create records one field at a time.",
    "Describe what you have in natural language."
  ],
  [
    "Start from an empty inventory.",
    "Bring in existing inventory records or spreadsheets."
  ],
  [
    "Search by remembering exact item names or filters.",
    "Ask FindEZ about your inventory in plain language."
  ],
  [
    "Treat photos as separate from inventory entry.",
    "Use photo capture to help add items."
  ],
  [
    "Think of inventory as a static list.",
    "Treat inventory as information you can talk to."
  ]
];
export const TITLES: Record<PageKey,string> = {
  "home": "FindEZ AI | AI Inventory for Parts, Tools & Equipment",
  "solutions": "Solutions | FindEZ AI",
  "founders": "Free Founders Access | FindEZ AI",
  "plans": "Plans & access | FindEZ AI",
  "sol:robotics": "Robotics Inventory for FTC & FRC Teams | FindEZ AI",
  "sol:workshops": "Workshop Inventory for Tools, Parts & Equipment | FindEZ AI",
  "sol:makers": "Makerspace Inventory for Components & Shared Tools | FindEZ AI",
  "sol:labs": "Engineering Lab Inventory | FindEZ AI",
  "sol:home": "Home Inventory for Everyday Things | FindEZ AI"
};
export const IC: Record<string,string> = {
  "sheet": "<rect x=\"3\" y=\"4\" width=\"18\" height=\"16\" rx=\"2.5\"/><path d=\"M3 9.5h18M3 15h18M9 4v16\"/>",
  "cam": "<path d=\"M4 8.5A2.5 2.5 0 0 1 6.5 6h1.2l1.4-2h5.8l1.4 2h1.2A2.5 2.5 0 0 1 20 8.5v8A2.5 2.5 0 0 1 17.5 19h-11A2.5 2.5 0 0 1 4 16.5Z\"/><circle cx=\"12\" cy=\"12.5\" r=\"3.5\"/>",
  "chat": "<path d=\"M20 12a8 8 0 0 1-11.6 7.1L4 20l1-4.1A8 8 0 1 1 20 12Z\"/>",
  "arrow": "<path d=\"M5 12h14M13 6l6 6-6 6\"/>",
  "plus": "<path d=\"M12 5v14M5 12h14\"/>",
  "ck": "<path d=\"M20 6 9 17l-5-5\"/>",
  "box": "<path d=\"M3 7.5 12 3l9 4.5v9L12 21l-9-4.5Z\"/><path d=\"M3 7.5 12 12l9-4.5M12 12v9\"/>"
};
export const TINT: Record<Audience,string> = {
  "robotics": "#E0875A",
  "workshops": "#C48E93",
  "makers": "#93A6BE",
  "labs": "#D2A86E",
  "home": "#9DB497"
};
export const FZ_IMG:Record<string,string> = Object.fromEntries(Array.from({length:7},(_,i)=>[`p${i}`,`/landing/thumbs/p${i}.jpg`]));
export const FZ_WASH='/landing/washers.jpg';
export const BENCH='/landing/workbench-web.jpg';
export const ROUTES:Record<string,string> = {'/':'/','/solutions':'/solutions','/robotics':'/solutions/robotics','/workshops':'/solutions/workshops','/makers':'/solutions/makerspaces','/labs':'/solutions/engineering-labs','/home':'/solutions/everyday','/founders':'/founders','/plans':'/pricing'};
export const EXT={signup:'/signup',signin:'/signin',ios:'https://apps.apple.com/us/app/findez-ai/id6760401697',docs:'/docs/api',research:'/research',contact:'mailto:info@findez.ai',privacy:'/privacy',terms:'/terms'};
