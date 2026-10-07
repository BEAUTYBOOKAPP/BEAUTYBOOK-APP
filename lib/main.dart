import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'l10n.dart';

late final SupabaseClient db;

const currencySymbols = {
  'CFA': 'CFA',
  'NGN': '₦',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
};

String showPrice(dynamic amount, dynamic currency) {
  final code = (currency ?? 'CFA').toString();
  final symbol = currencySymbols[code] ?? code;
  if (code == 'CFA') return '$amount CFA';
  return '$symbol$amount';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.configured) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabasePublishableKey);
    db = Supabase.instance.client;
  }
  runApp(const BeautyBook());
}

class BeautyBook extends StatelessWidget {
  const BeautyBook({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'BEAUTYBOOK',
    supportedLocales:L.supported,
    localizationsDelegates:[GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff8e4162)),scaffoldBackgroundColor:const Color(0xfffffafc)),
    home: AppConfig.configured ? const AuthGate() : const SetupScreen());
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Padding(
    padding:const EdgeInsets.all(24), child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('BEAUTYBOOK',style:TextStyle(fontSize:32,fontWeight:FontWeight.w900)),
      const SizedBox(height:12),
      const Text('Backend configuration required',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      const Text('Create a Supabase project, run supabase/schema.sql, then launch Flutter with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY dart-defines. Never put a service-role secret in this mobile app.'),
      const SizedBox(height:18),
      SelectableText('flutter run --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY',style:TextStyle(color:Theme.of(context).colorScheme.primary))
    ]))));
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override Widget build(BuildContext context)=>StreamBuilder<AuthState>(
    stream:db.auth.onAuthStateChange,
    builder:(_,__)=>db.auth.currentSession==null?const LoginPage():const Shell());
}

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState()=>_LoginPageState(); }
class _LoginPageState extends State<LoginPage>{
  final email=TextEditingController(), password=TextEditingController(), name=TextEditingController(), code=TextEditingController();
  bool signup=false, busy=false, awaitingVerification=false;
  String pendingEmail='', pendingPassword='';

  void message(String text){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
  }

  Future<void> submit() async {
    final e=email.text.trim();
    final p=password.text;
    final n=name.text.trim();

    if(e.isEmpty||!e.contains('@')){
      message('Enter a valid email address.');
      return;
    }
    if(p.length<6){
      message('Password must be at least 6 characters.');
      return;
    }
    if(signup&&n.isEmpty){
      message('Enter your full name.');
      return;
    }

    setState(()=>busy=true);
    try{
      if(signup){
        final res=await db.auth.signUp(
          email:e,
          password:p,
          data:{'full_name':n},
        );

        if(res.session!=null){
          await db.auth.signOut();
          message('Email verification is not enabled yet. Turn on Confirm email in Supabase before public launch.');
        }else{
          pendingEmail=e;
          pendingPassword=p;
          code.clear();
          if(mounted)setState(()=>awaitingVerification=true);
          message('Verification code sent to $e.');
        }
      } else {
        await db.auth.signInWithPassword(email:e,password:p);
        message('Welcome back.');
      }
    }catch(e){
      message(e.toString());
    }
    if(mounted)setState(()=>busy=false);
  }

  Future<void> verifyCode()async{
    final token=code.text.trim().replaceAll(' ','');
    if(token.length<6){
      message('Enter the verification code from your email.');
      return;
    }
    setState(()=>busy=true);
    try{
      final res=await db.auth.verifyOTP(
        email:pendingEmail,
        token:token,
        type:OtpType.email,
      );
      if(res.session==null){
        await db.auth.signInWithPassword(email:pendingEmail,password:pendingPassword);
      }
      message('Email verified. Welcome to BEAUTYBOOK.');
    }catch(e){
      message('Verification failed: $e');
    }
    if(mounted)setState(()=>busy=false);
  }

  Future<void> resendCode()async{
    if(pendingEmail.isEmpty)return;
    setState(()=>busy=true);
    try{
      await db.auth.resend(type:OtpType.signup,email:pendingEmail);
      message('A new verification code was sent.');
    }catch(e){
      message(e.toString());
    }
    if(mounted)setState(()=>busy=false);
  }

  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:ListView(padding:const EdgeInsets.all(24),children:[
    const SizedBox(height:45),
    const Text('BEAUTYBOOK',style:TextStyle(fontSize:32,fontWeight:FontWeight.w900)),
    if(awaitingVerification)...[
      const SizedBox(height:8),
      const Text('Verify your email',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      const SizedBox(height:6),
      Text('We sent a verification code to $pendingEmail.',style:const TextStyle(color:Colors.black54)),
      const SizedBox(height:24),
      TextField(
        controller:code,
        keyboardType:TextInputType.number,
        textInputAction:TextInputAction.done,
        decoration:const InputDecoration(
          labelText:'Verification code',
          hintText:'Enter the code from your email',
          border:OutlineInputBorder(),
        ),
        onSubmitted:(_){if(!busy)verifyCode();},
      ),
      const SizedBox(height:18),
      FilledButton(onPressed:busy?null:verifyCode,child:Text(busy?'Verifying...':'Verify and continue')),
      TextButton(onPressed:busy?null:resendCode,child:const Text('Resend code')),
      TextButton(
        onPressed:busy?null:()=>setState((){awaitingVerification=false;code.clear();}),
        child:const Text('Use a different email'),
      ),
    ] else ...[
      Text(signup?'Create your account':'Beauty • Fashion • Your Style',style:const TextStyle(color:Colors.black54)),
      const SizedBox(height:30),
      if(signup) TextField(controller:name,textCapitalization:TextCapitalization.words,decoration:const InputDecoration(labelText:'Full name',border:OutlineInputBorder())),
      if(signup) const SizedBox(height:12),
      TextField(controller:email,keyboardType:TextInputType.emailAddress,autocorrect:false,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Password',border:OutlineInputBorder())),
      const SizedBox(height:18),
      FilledButton(onPressed:busy?null:submit,child:Text(busy?'Please wait...':signup?'Create account':'Sign in')),
      TextButton(
        onPressed:busy?null:()=>setState(()=>signup=!signup),
        child:Text(signup?'Already have an account? Sign in':'New to BEAUTYBOOK? Create account'),
      )
    ]
  ])));
}

class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState()=>_ShellState(); }
class _ShellState extends State<Shell>{
  int i=0;
  @override Widget build(BuildContext context){
    final pages=[const Home(),const Shop(),const Bookings(),const Seller(),const Profile()];
    return Scaffold(body:SafeArea(child:pages[i]),bottomNavigationBar:NavigationBar(selectedIndex:i,onDestinationSelected:(x)=>setState(()=>i=x),destinations:const[
      NavigationDestination(icon:Icon(Icons.home_outlined),label:'Home'),
      NavigationDestination(icon:Icon(Icons.shopping_bag_outlined),label:'Shop'),
      NavigationDestination(icon:Icon(Icons.calendar_month_outlined),label:'Bookings'),
      NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'Sell'),
      NavigationDestination(icon:Icon(Icons.person_outline),label:'Profile'),
    ]));
  }
}

class Home extends StatelessWidget{
  const Home({super.key});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    const Text('BEAUTYBOOK',style:TextStyle(fontSize:27,fontWeight:FontWeight.w900)),
    const Text('Beauty • Fashion • Your Style'),
    const SizedBox(height:18),
    Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:const Color(0xff8e4162),borderRadius:BorderRadius.circular(24)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Book beauty. Shop fashion.',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.bold)),
      Text('Discover professionals, clothing, wigs, shoes, bags and accessories.',style:TextStyle(color:Colors.white70))
    ])),
    const SizedBox(height:22), const Text('Beauty professionals',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    const Professionals()
  ]);
}

class Professionals extends StatelessWidget{
  const Professionals({super.key});
  @override Widget build(BuildContext context)=>FutureBuilder(
    future:db.from('businesses').select('id,name,business_type,category,location,whatsapp,verified').eq('active',true).order('created_at').limit(30),
    builder:(context,s){
      if(!s.hasData)return const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator()));
      final rows=(s.data as List).where((x)=>x['business_type']=='beauty'||['braids','hair','nails','makeup','barber'].contains(x['category'])).toList();
      if(rows.isEmpty)return const Padding(padding:EdgeInsets.symmetric(vertical:20),child:Text('No professionals listed yet.'));
      return Column(children:rows.map((b)=>Card(child:ListTile(
        leading:const CircleAvatar(child:Icon(Icons.face_3)),title:Text(b['name']),subtitle:Text('${b['category']} • ${b['location']??''}'),
        trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ProPage(b:b)))
      ))).toList());
    });
}

class ProPage extends StatefulWidget{final Map b; const ProPage({super.key,required this.b}); @override State<ProPage> createState()=>_ProPageState();}
class _ProPageState extends State<ProPage>{
  Map? selected; DateTime day=DateTime.now().add(const Duration(days:1)); String time='10:00'; bool busy=false;
  Future<void> book()async{
    if(selected==null)return;
    setState(()=>busy=true);
    try{
      await db.from('bookings').insert({'customer_id':db.auth.currentUser!.id,'business_id':widget.b['id'],'service_id':selected!['id'],'booking_date':'${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}','booking_time':'$time:00'});
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Booking request sent.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    if(mounted)setState(()=>busy=false);
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.b['name'])),body:FutureBuilder(
    future:db.from('services').select().eq('business_id',widget.b['id']).eq('active',true),
    builder:(context,s){
      final sv=s.data as List? ?? [];
      return ListView(padding:const EdgeInsets.all(20),children:[
        const CircleAvatar(radius:50,child:Icon(Icons.face_3,size:48)),const SizedBox(height:12),
        Center(child:Text(widget.b['name'],style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold))),
        Center(child:Text(widget.b['location']??'')),const SizedBox(height:22),
        DropdownButtonFormField<Map>(value:selected,decoration:const InputDecoration(labelText:'Service',border:OutlineInputBorder()),
          items:sv.map((x)=>DropdownMenuItem<Map>(value:x,child:Text("${x['name']} • ${showPrice(x['price_cfa'], x['currency_code'])}"))).toList(),onChanged:(v)=>setState(()=>selected=v)),
        ListTile(contentPadding:EdgeInsets.zero,title:const Text('Date'),subtitle:Text('${day.day}/${day.month}/${day.year}'),trailing:const Icon(Icons.calendar_month),onTap:()async{
          final d=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:180)),initialDate:day); if(d!=null)setState(()=>day=d);
        }),
        Wrap(spacing:8,children:['09:00','10:00','12:00','14:00','16:00'].map((x)=>ChoiceChip(label:Text(x),selected:time==x,onSelected:(_)=>setState(()=>time=x))).toList()),
        const SizedBox(height:22),FilledButton(onPressed:busy?null:book,child:Text(busy?'Sending...':'Request booking'))
      ]);
    }));
}

class Shop extends StatefulWidget{const Shop({super.key});@override State<Shop> createState()=>_ShopState();}
class _ShopState extends State<Shop>{
  String q='';
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    const Text('Fashion Shop',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),
    const SizedBox(height:12),TextField(onChanged:(v)=>setState(()=>q=v.toLowerCase()),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search gowns, wigs, bags...',border:OutlineInputBorder())),
    const SizedBox(height:16),
    FutureBuilder(future:db.from('products').select('*,businesses(name,whatsapp,location)').eq('active',true).gt('stock',0).order('created_at'),
      builder:(context,s){
        if(!s.hasData)return const Center(child:CircularProgressIndicator());
        final all=(s.data as List).where((p)=>q.isEmpty||(p['name'] as String).toLowerCase().contains(q)).toList();
        return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:all.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:.72,crossAxisSpacing:12,mainAxisSpacing:12),itemBuilder:(_,i)=>ProductCard(p:all[i]));
      })
  ]);
}

class ProductCard extends StatelessWidget{
  final Map p; const ProductCard({super.key,required this.p});
  Future<void> order(BuildContext context)async{
    final phone=(p['businesses']?['whatsapp']??'').toString().replaceAll(RegExp(r'[^0-9]'),'');
    if(phone.isEmpty){
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('This seller has not added a WhatsApp number yet.')));
      return;
    }
    final u=Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent("Hello, I found ${p['name']} on BEAUTYBOOK. Is it available?")}');
    final opened=await launchUrl(u,mode:LaunchMode.externalApplication);
    if(!opened&&context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Unable to open WhatsApp.')));
  }
  Future<void> fav(BuildContext context)async{
    try{await db.from('favorites').insert({'user_id':db.auth.currentUser!.id,'product_id':p['id']}); if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Added to favorites.')));}
    catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Already saved or unable to save.')));}
  }
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(12),child:p['image_url']!=null?Image.network(p['image_url'],width:double.infinity,fit:BoxFit.cover):Container(color:const Color(0xfff7e6ed),child:const Center(child:Icon(Icons.checkroom,size:55))))),
    const SizedBox(height:8),Text(p['name'],maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold)),
    Text(showPrice(p['price_cfa'], p['currency_code']),style:const TextStyle(color:Color(0xff8e4162),fontWeight:FontWeight.bold)),
    Row(children:[IconButton(onPressed:()=>fav(context),icon:const Icon(Icons.favorite_border)),Expanded(child:FilledButton(onPressed:()=>order(context),child:const Text('Order')))])
  ])));
}

class Bookings extends StatelessWidget{
  const Bookings({super.key});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    const Text('My Bookings',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),const SizedBox(height:14),
    FutureBuilder(future:db.from('bookings').select('*,businesses(name),services(name,price_cfa)').eq('customer_id',db.auth.currentUser!.id).order('created_at',ascending:false),
      builder:(context,s){
        if(!s.hasData)return const Center(child:CircularProgressIndicator());
        final x=s.data as List;if(x.isEmpty)return const Text('No bookings yet.');
        return Column(children:x.map((b)=>Card(child:ListTile(leading:const Icon(Icons.calendar_month),title:Text(b['services']?['name']??'Service'),subtitle:Text('${b['businesses']?['name']??''}\n${b['booking_date']} • ${b['booking_time']}'),isThreeLine:true,trailing:Chip(label:Text(b['status']))))).toList());
      })
  ]);
}

class Seller extends StatefulWidget{const Seller({super.key});@override State<Seller> createState()=>_SellerState();}
class _SellerState extends State<Seller>{
  final name=TextEditingController(),price=TextEditingController(),stock=TextEditingController();
  String category='clothing', currency='CFA';
  XFile? photo;
  bool busy=false;

  Future<Map?> myBusiness() async {
    final x=await db.from('businesses').select().eq('owner_id',db.auth.currentUser!.id).limit(1);
    return x.isEmpty?null:Map<String,dynamic>.from(x.first);
  }

  Future<void> businessForm([Map? existing])async{
    const categoryOptions=<String,String>{
      'fashion & beauty':'Fashion & beauty',
      'beauty':'Beauty / general',
      'hair salon':'Hair salon',
      'braiding':'Braiding',
      'barber':'Barber',
      'nails':'Nails',
      'makeup':'Makeup',
      'spa':'Spa',
      'skincare':'Skincare',
      'clothing':'Clothing / boutique',
      'wigs & hair':'Wigs & hair',
      'shoes':'Shoes',
      'bags & accessories':'Bags & accessories',
      'beauty products':'Beauty products / cosmetics',
      'other':'Other',
    };

    const countries=<String>[
      'Afghanistan',
      'Albania',
      'Algeria',
      'American Samoa',
      'Andorra',
      'Angola',
      'Anguilla',
      'Antarctica',
      'Antigua and Barbuda',
      'Argentina',
      'Armenia',
      'Aruba',
      'Australia',
      'Austria',
      'Azerbaijan',
      'Bahamas',
      'Bahrain',
      'Bangladesh',
      'Barbados',
      'Belarus',
      'Belgium',
      'Belize',
      'Benin',
      'Bermuda',
      'Bhutan',
      'Bolivia',
      'Bonaire, Sint Eustatius and Saba',
      'Bosnia and Herzegovina',
      'Botswana',
      'Bouvet Island',
      'Brazil',
      'British Indian Ocean Territory',
      'Brunei',
      'Bulgaria',
      'Burkina Faso',
      'Burundi',
      'Cabo Verde',
      'Cambodia',
      'Cameroon',
      'Canada',
      'Cayman Islands',
      'Central African Republic',
      'Chad',
      'Chile',
      'China',
      'Christmas Island',
      'Cocos (Keeling) Islands',
      'Colombia',
      'Comoros',
      'Congo',
      'Cook Islands',
      'Costa Rica',
      'Croatia',
      'Cuba',
      'Curaçao',
      'Cyprus',
      'Czechia',
      "Côte d'Ivoire",
      'DR Congo',
      'Denmark',
      'Djibouti',
      'Dominica',
      'Dominican Republic',
      'Ecuador',
      'Egypt',
      'El Salvador',
      'Equatorial Guinea',
      'Eritrea',
      'Estonia',
      'Eswatini',
      'Ethiopia',
      'Falkland Islands (Malvinas)',
      'Faroe Islands',
      'Fiji',
      'Finland',
      'France',
      'French Guiana',
      'French Polynesia',
      'French Southern Territories',
      'Gabon',
      'Gambia',
      'Georgia',
      'Germany',
      'Ghana',
      'Gibraltar',
      'Greece',
      'Greenland',
      'Grenada',
      'Guadeloupe',
      'Guam',
      'Guatemala',
      'Guernsey',
      'Guinea',
      'Guinea-Bissau',
      'Guyana',
      'Haiti',
      'Heard Island and McDonald Islands',
      'Holy See (Vatican City State)',
      'Honduras',
      'Hong Kong',
      'Hungary',
      'Iceland',
      'India',
      'Indonesia',
      'Iran',
      'Iraq',
      'Ireland',
      'Isle of Man',
      'Israel',
      'Italy',
      'Jamaica',
      'Japan',
      'Jersey',
      'Jordan',
      'Kazakhstan',
      'Kenya',
      'Kiribati',
      'Kuwait',
      'Kyrgyzstan',
      'Laos',
      'Latvia',
      'Lebanon',
      'Lesotho',
      'Liberia',
      'Libya',
      'Liechtenstein',
      'Lithuania',
      'Luxembourg',
      'Macao',
      'Madagascar',
      'Malawi',
      'Malaysia',
      'Maldives',
      'Mali',
      'Malta',
      'Marshall Islands',
      'Martinique',
      'Mauritania',
      'Mauritius',
      'Mayotte',
      'Mexico',
      'Micronesia, Federated States of',
      'Moldova',
      'Monaco',
      'Mongolia',
      'Montenegro',
      'Montserrat',
      'Morocco',
      'Mozambique',
      'Myanmar',
      'Namibia',
      'Nauru',
      'Nepal',
      'Netherlands',
      'New Caledonia',
      'New Zealand',
      'Nicaragua',
      'Niger',
      'Nigeria',
      'Niue',
      'Norfolk Island',
      'North Korea',
      'North Macedonia',
      'Northern Mariana Islands',
      'Norway',
      'Oman',
      'Pakistan',
      'Palau',
      'Palestine',
      'Panama',
      'Papua New Guinea',
      'Paraguay',
      'Peru',
      'Philippines',
      'Pitcairn',
      'Poland',
      'Portugal',
      'Puerto Rico',
      'Qatar',
      'Romania',
      'Russia',
      'Rwanda',
      'Réunion',
      'Saint Barthélemy',
      'Saint Helena, Ascension and Tristan da Cunha',
      'Saint Kitts and Nevis',
      'Saint Lucia',
      'Saint Martin (French part)',
      'Saint Pierre and Miquelon',
      'Saint Vincent and the Grenadines',
      'Samoa',
      'San Marino',
      'Sao Tome and Principe',
      'Saudi Arabia',
      'Senegal',
      'Serbia',
      'Seychelles',
      'Sierra Leone',
      'Singapore',
      'Sint Maarten (Dutch part)',
      'Slovakia',
      'Slovenia',
      'Solomon Islands',
      'Somalia',
      'South Africa',
      'South Georgia and the South Sandwich Islands',
      'South Korea',
      'South Sudan',
      'Spain',
      'Sri Lanka',
      'Sudan',
      'Suriname',
      'Svalbard and Jan Mayen',
      'Sweden',
      'Switzerland',
      'Syria',
      'Taiwan',
      'Tajikistan',
      'Tanzania',
      'Thailand',
      'Timor-Leste',
      'Togo',
      'Tokelau',
      'Tonga',
      'Trinidad and Tobago',
      'Tunisia',
      'Turkmenistan',
      'Turks and Caicos Islands',
      'Tuvalu',
      'Türkiye',
      'Uganda',
      'Ukraine',
      'United Arab Emirates',
      'United Kingdom',
      'United States',
      'United States Minor Outlying Islands',
      'Uruguay',
      'Uzbekistan',
      'Vanuatu',
      'Venezuela',
      'Vietnam',
      'Virgin Islands, British',
      'Virgin Islands, U.S.',
      'Wallis and Futuna',
      'Western Sahara',
      'Yemen',
      'Zambia',
      'Zimbabwe',
      'Åland Islands'
    ];

    final businessName=TextEditingController(text:existing==null?'':(existing['name']??'').toString());
    final whatsapp=TextEditingController(text:existing==null?'':(existing['whatsapp']??'').toString());

    final existingLocation=(existing==null?'':(existing['location']??'').toString()).trim();
    String cityValue=existingLocation;
    String? countryValue;
    if(existingLocation.contains(',')){
      final parts=existingLocation.split(',');
      final possibleCountry=parts.removeLast().trim();
      if(countries.contains(possibleCountry)){
        countryValue=possibleCountry;
        cityValue=parts.join(',').trim();
      }
    }
    final city=TextEditingController(text:cityValue);

    final existingCategory=(existing==null?'fashion & beauty':(existing['category']??'fashion & beauty').toString()).trim().toLowerCase();
    String categoryChoice=categoryOptions.containsKey(existingCategory)?existingCategory:'other';
    final customCategory=TextEditingController(text:categoryChoice=='other'?existingCategory:'');

    String type=existing==null?'both':(existing['business_type']??'both').toString();
    if(!['beauty','fashion','both'].contains(type))type='both';
    bool saving=false;

    Future<String?> chooseCountry(BuildContext pickerContext,String? current)async{
      String search='';
      return showDialog<String>(
        context:pickerContext,
        builder:(countryContext)=>StatefulBuilder(
          builder:(countryContext,setCountryState){
            final visible=countries.where((x)=>x.toLowerCase().contains(search.toLowerCase())).toList();
            return AlertDialog(
              title:const Text('Select country'),
              content:SizedBox(
                width:double.maxFinite,
                height:430,
                child:Column(children:[
                  TextField(
                    autofocus:true,
                    decoration:const InputDecoration(
                      hintText:'Search country',
                      prefixIcon:Icon(Icons.search),
                      border:OutlineInputBorder(),
                    ),
                    onChanged:(v)=>setCountryState(()=>search=v),
                  ),
                  const SizedBox(height:8),
                  Expanded(child:ListView.builder(
                    itemCount:visible.length,
                    itemBuilder:(context,index){
                      final item=visible[index];
                      return ListTile(
                        title:Text(item),
                        trailing:item==current?const Icon(Icons.check):null,
                        onTap:()=>Navigator.of(countryContext).pop(item),
                      );
                    },
                  )),
                ]),
              ),
              actions:[TextButton(onPressed:()=>Navigator.of(countryContext).pop(),child:const Text('Cancel'))],
            );
          },
        ),
      );
    }

    await showDialog<void>(
      context:context,
      builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>AlertDialog(
        title:Text(existing==null?'Create your business':'Edit business'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:businessName,decoration:const InputDecoration(labelText:'Business name',border:OutlineInputBorder())),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
            value:type,
            decoration:const InputDecoration(labelText:'Business type',border:OutlineInputBorder()),
            items:const [
              DropdownMenuItem(value:'fashion',child:Text('Fashion / products')),
              DropdownMenuItem(value:'beauty',child:Text('Beauty professional')),
              DropdownMenuItem(value:'both',child:Text('Beauty + fashion')),
            ],
            onChanged:saving?null:(v)=>setDialogState(()=>type=v!),
          ),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
            value:categoryChoice,
            decoration:const InputDecoration(labelText:'Category',border:OutlineInputBorder()),
            items:categoryOptions.entries.map((e)=>DropdownMenuItem<String>(value:e.key,child:Text(e.value))).toList(),
            onChanged:saving?null:(v)=>setDialogState(()=>categoryChoice=v!),
          ),
          if(categoryChoice=='other')...[
            const SizedBox(height:10),
            TextField(controller:customCategory,decoration:const InputDecoration(labelText:'Your category',hintText:'Type your business category',border:OutlineInputBorder())),
          ],
          const SizedBox(height:10),
          TextField(controller:city,decoration:const InputDecoration(labelText:'City / area',hintText:'e.g. Lomé',border:OutlineInputBorder())),
          const SizedBox(height:10),
          InkWell(
            onTap:saving?null:()async{
              final picked=await chooseCountry(dialogContext,countryValue);
              if(picked!=null)setDialogState(()=>countryValue=picked);
            },
            child:InputDecorator(
              decoration:const InputDecoration(labelText:'Country',border:OutlineInputBorder(),suffixIcon:Icon(Icons.arrow_drop_down)),
              child:Text(countryValue??'Select country',style:TextStyle(color:countryValue==null?Colors.black54:null)),
            ),
          ),
          const SizedBox(height:10),
          TextField(controller:whatsapp,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'WhatsApp number',hintText:'+228 90 00 00 00',border:OutlineInputBorder())),
        ])),
        actions:[
          TextButton(onPressed:saving?null:()=>Navigator.of(dialogContext).pop(),child:const Text('Cancel')),
          FilledButton(
            onPressed:saving?null:()async{
              final bn=businessName.text.trim();
              final wa=whatsapp.text.trim();
              final cityText=city.text.trim();
              final cat=(categoryChoice=='other'?customCategory.text.trim():categoryChoice).trim();
              final digits=wa.replaceAll(RegExp(r'[^0-9]'),'');
              if(bn.isEmpty||wa.isEmpty||cityText.isEmpty||countryValue==null||cat.isEmpty){
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Please complete every business field.')));
                return;
              }
              if(digits.length<8){
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a valid WhatsApp number with country code.')));
                return;
              }
              setDialogState(()=>saving=true);
              try{
                final loc='$cityText, $countryValue';
                final payload={
                  'owner_id':db.auth.currentUser!.id,
                  'name':bn,
                  'business_name':bn,
                  'business_type':type,
                  'category':cat.toLowerCase(),
                  'location':loc,
                  'whatsapp':wa,
                  'verified':existing==null?false:(existing['verified']??false),
                  'active':true
                };
                if(existing==null){
                  await db.from('businesses').insert(payload);
                }else{
                  await db.from('businesses').update(payload).eq('id',existing['id']);
                }
                await db.from('profiles').update({'role':'seller'}).eq('id',db.auth.currentUser!.id);
                if(dialogContext.mounted)Navigator.of(dialogContext).pop();
                if(mounted){
                  setState((){});
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(existing==null?'Business created.':'Business updated.')));
                }
              }catch(e){
                if(dialogContext.mounted)setDialogState(()=>saving=false);
                if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
              }
            },
            child:Text(saving?'Saving...':existing==null?'Create business':'Save changes'),
          )
        ],
      )),
    );
    businessName.dispose();
    whatsapp.dispose();
    city.dispose();
    customCategory.dispose();
  }

  Future<void> add()async{
    final b=await myBusiness();
    if(b==null){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Create your BEAUTYBOOK business first.')));
      return;
    }
    final productName=name.text.trim();
    final productPrice=int.tryParse(price.text.trim());
    final productStock=int.tryParse(stock.text.trim());
    if(productName.isEmpty||productPrice==null||productPrice<0||productStock==null||productStock<0){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a product name, valid price and valid stock quantity.')));
      return;
    }
    setState(()=>busy=true);
    try{
      String? url;
      if(photo!=null){
        final ext=photo!.name.split('.').last;
        final path='${db.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await db.storage.from('product-images').upload(path,File(photo!.path));
        url=db.storage.from('product-images').getPublicUrl(path);
      }
      await db.from('products').insert({
        'business_id':b['id'],
        'name':productName,
        'name_en':productName,
        'name_fr':productName,
        'category':category,
        'price_cfa':productPrice,
        'currency_code':currency,
        'stock':productStock,
        'image_url':url,
        'active':true
      });
      name.clear();price.clear();stock.clear();photo=null;
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Product published.')));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));
    }
    if(mounted)setState(()=>busy=false);
  }

  @override Widget build(BuildContext context)=>ListView(
    padding:const EdgeInsets.all(18),
    children:[
      const Text('Seller Studio',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),
      const Text('Create your business, then add products for customers to discover.'),
      const SizedBox(height:10),
      FutureBuilder<Map?>(
        future:myBusiness(),
        builder:(context,s)=>s.connectionState!=ConnectionState.done
          ? const LinearProgressIndicator()
          : s.data==null
            ? FilledButton.icon(onPressed:()=>businessForm(),icon:const Icon(Icons.storefront),label:const Text('Create my BEAUTYBOOK business'))
            : Card(child:Column(children:[
                ListTile(
                  leading:const Icon(Icons.verified_user_outlined),
                  title:Text(s.data!['name']??'Business'),
                  subtitle:Text('${s.data!['category']??''} • ${s.data!['location']??''}\n${s.data!['whatsapp']??''}'),
                  isThreeLine:true,
                ),
                Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>businessForm(s.data),icon:const Icon(Icons.edit_outlined),label:const Text('Edit business')))
              ])),
      ),
      const SizedBox(height:18),
      TextField(controller:name,decoration:const InputDecoration(labelText:'Product name',border:OutlineInputBorder())),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(
        value:category,
        decoration:const InputDecoration(labelText:'Product category',border:OutlineInputBorder()),
        items:['clothing','wigs','shoes','bags','accessories','beauty products'].map((x)=>DropdownMenuItem<String>(value:x,child:Text(x))).toList(),
        onChanged:(v)=>setState(()=>category=v!),
      ),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(
        value:currency,
        decoration:const InputDecoration(labelText:'Currency',border:OutlineInputBorder()),
        items:['CFA','NGN','USD','EUR','GBP'].map((x)=>DropdownMenuItem<String>(value:x,child:Text(x))).toList(),
        onChanged:(v)=>setState(()=>currency=v!),
      ),
      const SizedBox(height:10),
      TextField(controller:price,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Price ($currency)',border:const OutlineInputBorder())),
      const SizedBox(height:10),
      TextField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Stock quantity',border:OutlineInputBorder())),
      const SizedBox(height:12),
      OutlinedButton.icon(
        onPressed:()async{final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:80);if(x!=null)setState(()=>photo=x);},
        icon:const Icon(Icons.image),
        label:Text(photo==null?'Choose product photo':'Photo selected'),
      ),
      FilledButton(onPressed:busy?null:add,child:Text(busy?'Publishing...':'Publish product'))
    ],
  );
}

class Profile extends StatelessWidget{
  const Profile({super.key});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    const Text('Profile',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),const SizedBox(height:15),
    ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(db.auth.currentUser?.userMetadata?['full_name']??'BEAUTYBOOK user'),subtitle:Text(db.auth.currentUser?.email??'')),
    const ListTile(leading:Icon(Icons.language),title:Text('Languages'),subtitle:Text('English • Français (UI localization ready for expansion)')),
    ListTile(leading:const Icon(Icons.logout),title:const Text('Sign out'),onTap:()=>db.auth.signOut())
  ]);
}
