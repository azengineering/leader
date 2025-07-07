export const indianStates: string[] = [
  "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh",
  "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka",
  "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya",
  "Mizoram", "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim",
  "Tamil Nadu", "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal", "Delhi"
];

export const districtsByState: Record<string, string[]> = {
  "Maharashtra": [
    "Mumbai North", "Mumbai North West", "Mumbai North East", "Mumbai North Central", 
    "Mumbai South Central", "Mumbai South", "Pune", "Baramati", "Shirur", "Ahmednagar", 
    "Shirdi", "Nashik", "Maval", "Chinchwad", "Nagpur", "Ramtek", "Bhandara-Gondiya", 
    "Gadchiroli-Chimur", "Chandrapur", "Wardha", "Yavatmal-Washim", "Hingoli", "Nanded", 
    "Parbhani", "Jalna", "Aurangabad", "Dindori", "Nashik", "Dhule", "Nandurbar", 
    "Jalgaon", "Raver", "Buldhana", "Akola", "Amravati", "Wardha", "Nagpur", "Bhandara-Gondiya", 
    "Gadchiroli-Chimur", "Chandrapur", "Yavatmal-Washim", "Washim", "Buldhana", "Akola", 
    "Melghat", "Amravati", "Wardha", "Ramtek", "Nagpur", "Kamptee"
  ],
  "Karnataka": [
    "Chikkaballapur", "Bangalore Rural", "Bangalore North", "Bangalore Central", 
    "Bangalore South", "Chikkaballapura", "Kolar", "Bangalore Rural", "Hassan", 
    "Dakshina Kannada", "Udupi Chikmagalur", "Shimoga", "Haveri", "Dharwad", 
    "Uttara Kannada", "Belagavi", "Bagalkot", "Bijapur", "Gulbarga", "Raichur", 
    "Bidar", "Koppal", "Bellary", "Haveri", "Gadag", "Bagalkot", "Bijapur", 
    "Gulbarga", "Raichur", "Bidar", "Koppal", "Bellary", "Chitradurga", "Davanagere", 
    "Shimoga", "Udupi Chikmagalur", "Dakshina Kannada", "Uttara Kannada", "Haveri", 
    "Dharwad", "Belagavi", "Chikkodi", "Belgaum", "Bagalkot", "Bijapur", "Gulbarga"
  ],
  "Uttar Pradesh": [
    "Saharanpur", "Kairana", "Muzaffarnagar", "Bijnor", "Nagina", "Moradabad", 
    "Rampur", "Sambhal", "Amroha", "Meerut", "Baghpat", "Ghaziabad", "Gautam Buddha Nagar", 
    "Bulandshahr", "Aligarh", "Hathras", "Mathura", "Agra", "Fatehpur Sikri", 
    "Firozabad", "Mainpuri", "Etah", "Badaun", "Aonla", "Bareilly", "Pilibhit", 
    "Shahjahanpur", "Kheri", "Dhaurahra", "Sitapur", "Hardoi", "Misrikh", "Unnao", 
    "Mohanlalganj", "Lucknow", "Rae Bareli", "Amethi", "Sultanpur", "Pratapgarh", 
    "Farrukhabad", "Etawah", "Kannauj", "Kanpur", "Akbarpur", "Jalaun", "Jhansi", 
    "Hamirpur", "Banda", "Fatehpur", "Kaushambi", "Phulpur", "Allahabad", "Barabanki", 
    "Faizabad", "Ambedkar Nagar", "Bahraich", "Kaiserganj", "Shrawasti", "Gonda", 
    "Domariyaganj", "Basti", "Sant Kabir Nagar", "Maharajganj", "Gorakhpur", 
    "Kushi Nagar", "Deoria", "Bansgaon", "Lalganj", "Azamgarh", "Ghosi", "Salempur", 
    "Ballia", "Jaunpur", "Machhlishahr", "Ghazipur", "Chandauli", "Varanasi", 
    "Bhadohi", "Mirzapur", "Robertsganj", "Sonbhadra"
  ],
  "Tamil Nadu": [
    "Thiruvallur", "Chennai North", "Chennai South", "Chennai Central", "Sriperumbudur", 
    "Kancheepuram", "Arakkonam", "Vellore", "Krishnagiri", "Dharmapuri", "Tiruvannamalai", 
    "Arani", "Viluppuram", "Kallakurichi", "Salem", "Namakkal", "Erode", "Tirupur", 
    "Nilgiris", "Coimbatore", "Pollachi", "Dindigul", "Karur", "Tiruchirappalli", 
    "Perambalur", "Cuddalore", "Chidambaram", "Mayiladuthurai", "Nagapattinam", 
    "Thanjavur", "Sivaganga", "Madurai", "Theni", "Virudhunagar", "Ramanathapuram", 
    "Thoothukkudi", "Tenkasi", "Tirunelveli", "Kanniyakumari"
  ],
  "Delhi": [
    "Chandni Chowk", "North East Delhi", "East Delhi", "New Delhi", "North West Delhi", 
    "West Delhi", "South Delhi"
  ],
  "Gujarat": [
    "Kachchh", "Banaskantha", "Patan", "Mahesana", "Sabarkantha", "Gandhinagar", 
    "Ahmedabad East", "Ahmedabad West", "Surendranagar", "Rajkot", "Porbandar", 
    "Jamnagar", "Junagadh", "Amreli", "Bhavnagar", "Anand", "Kheda", "Panchmahal", 
    "Dahod", "Vadodara", "Chhota Udaipur", "Bharuch", "Bardoli", "Surat", "Navsari", 
    "Valsad"
  ],
  "West Bengal": [
    "Cooch Behar", "Alipurduars", "Jalpaiguri", "Darjeeling", "Raiganj", "Balurghat", 
    "Maldaha Uttar", "Maldaha Dakshin", "Jangipur", "Baharampur", "Murshidabad", 
    "Krishnanagar", "Ranaghat", "Bangaon", "Barrackpore", "Dum Dum", "Barasat", 
    "Basirhat", "Jaynagar", "Mathurapur", "Diamond Harbour", "Jadavpur", "Kolkata Dakshin", 
    "Kolkata Uttar", "Howrah", "Uluberia", "Srerampur", "Hooghly", "Arambagh", 
    "Tamluk", "Kanthi", "Ghatal", "Jhargram", "Medinipur", "Purulia", "Bankura", 
    "Bishnupur", "Bardhaman Purba", "Bardhaman-Durgapur", "Asansol", "Bolpur", 
    "Birbhum"
  ],
  "Rajasthan": [
    "Ganganagar", "Bikaner", "Churu", "Jhunjhunu", "Sikar", "Jaipur Rural", 
    "Jaipur", "Alwar", "Bharatpur", "Karauli-Dholpur", "Dausa", "Tonk-Sawai Madhopur", 
    "Ajmer", "Nagaur", "Pali", "Jodhpur", "Barmer", "Jalore", "Udaipur", "Banswara", 
    "Chittorgarh", "Rajsamand", "Bhilwara", "Kota", "Jhalawar-Baran"
  ],
  "Madhya Pradesh": [
    "Morena", "Bhind", "Gwalior", "Guna", "Sagar", "Tikamgarh", "Damoh", "Khajuraho", 
    "Satna", "Rewa", "Sidhi", "Shahdol", "Jabalpur", "Mandla", "Balaghat", "Chhindwara", 
    "Hoshangabad", "Vidisha", "Bhopal", "Rajgarh", "Dewas", "Ujjain", "Mandsour", 
    "Ratlam", "Dhar", "Indore", "Khargone", "Khandwa", "Betul"
  ],
  "Bihar": [
    "Valmiki Nagar", "Paschim Champaran", "Purvi Champaran", "Sheohar", "Sitamarhi", 
    "Madhubani", "Jhanjharpur", "Supaul", "Araria", "Kishanganj", "Katihar", "Purnia", 
    "Madhepura", "Darbhanga", "Muzaffarpur", "Vaishali", "Gopalganj", "Siwan", 
    "Maharajganj", "Saran", "Chapra", "Hajipur", "Ujiarpur", "Samastipur", "Begusarai", 
    "Khagaria", "Munger", "Lakhisarai", "Sheikhpura", "Nalanda", "Patna Sahib", 
    "Pataliputra", "Arrah", "Buxar", "Sasaram", "Karakat", "Jahanabad", "Aurangabad", 
    "Gaya", "Nawada", "Jamui"
  ],
  "Andhra Pradesh": [
    "Araku", "Srikakulam", "Vizianagaram", "Visakhapatnam", "Anakapalli", "Kakinada", 
    "Amalapuram", "Eluru", "Machilipatnam", "Vijayawada", "Guntur", "Narasaraopet", 
    "Bapatla", "Ongole", "Nandyal", "Kurnool", "Anantapur", "Hindupur", "Kadapa", 
    "Nellore", "Tirupati", "Rajampet", "Chittoor"
  ],
  "Telangana": [
    "Adilabad", "Peddapalle", "Karimnagar", "Nizamabad", "Zahirabad", "Medak", 
    "Malkajgiri", "Secunderabad", "Hyderabad", "Chevella", "Mahbubnagar", "Nagarkurnool", 
    "Nalgonda", "Bhongir", "Warangal", "Mahabubabad", "Khammam"
  ],
  "Odisha": [
    "Bargarh", "Sundargarh", "Sambalpur", "Keonjhar", "Mayurbhanj", "Balasore", 
    "Bhadrak", "Jajpur", "Dhenkanal", "Cuttack", "Jagatsinghpur", "Puri", "Bhubaneswar", 
    "Pipili", "Nayagarh", "Phulbani", "Berhampur", "Koraput", "Nabarangpur", "Kalahandi", 
    "Bolangir"
  ],
  "Assam": [
    "Kokrajhar", "Dhubri", "Barpeta", "Gauhati", "Mangaldoi", "Tezpur", "Nowgong", 
    "Kaliabor", "Jorhat", "Dibrugarh", "Lakhimpur", "Autonomous District", "Karimganj", 
    "Silchar"
  ],
  "Kerala": [
    "Kasaragod", "Kannur", "Vatakara", "Kozhikode", "Malappuram", "Ponnani", "Palakkad", 
    "Alathur", "Thrissur", "Chalakudy", "Ernakulam", "Idukki", "Kottayam", "Alappuzha", 
    "Mavelikkara", "Pathanamthitta", "Kollam", "Attingal", "Thiruvananthapuram"
  ],
  "Punjab": [
    "Gurdaspur", "Amritsar", "Khadoor Sahib", "Jalandhar", "Hoshiarpur", "Anandpur Sahib", 
    "Ludhiana", "Fatehgarh Sahib", "Faridkot", "Firozpur", "Bathinda", "Sangrur", 
    "Patiala"
  ],
  "Haryana": [
    "Ambala", "Kurukshetra", "Sirsa", "Hisar", "Karnal", "Sonipat", "Rohtak", 
    "Bhiwani-Mahendragarh", "Gurgaon", "Faridabad"
  ],
  "Jharkhand": [
    "Rajmahal", "Dumka", "Godda", "Chatra", "Kodarma", "Giridih", "Dhanbad", 
    "Ranchi", "Jamshedpur", "Singhbhum", "Khunti", "Lohardaga", "Palamu", "Hazaribagh"
  ],
  "Chhattisgarh": [
    "Bastar", "Kanker", "Rajnandgaon", "Durg", "Raipur", "Mahasamund", "Korba", 
    "Janjgir-Champa", "Raigarh", "Surguja", "Bilaspur"
  ],
  "Himachal Pradesh": [
    "Kangra", "Mandi", "Hamirpur", "Shimla"
  ],
  "Uttarakhand": [
    "Tehri Garhwal", "Garhwal", "Almora", "Nainital-Udhamsingh Nagar", "Hardwar"
  ],
  "Goa": [
    "North Goa", "South Goa"
  ],
  "Manipur": [
    "Inner Manipur", "Outer Manipur"
  ],
  "Tripura": [
    "Tripura West", "Tripura East"
  ],
  "Meghalaya": [
    "Shillong", "Tura"
  ],
  "Mizoram": [
    "Mizoram"
  ],
  "Nagaland": [
    "Nagaland"
  ],
  "Arunachal Pradesh": [
    "Arunachal West", "Arunachal East"
  ],
  "Sikkim": [
    "Sikkim"
  ]
};
