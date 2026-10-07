import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'l10n.dart';

late final SupabaseClient db;

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
    localizationsDelegates:const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
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
  final email=TextEditingController(), password=TextEditingController(), name=TextEditingController();
  bool signup=false, busy=false;
  Future<void> submit() async {
    setState(()=>busy=true);
    try{
      if(signup){
        await db.auth.signUp(email:email.text.trim(),password:password.text,data:{'full_name':name.text.trim()});
      } else {
        await db.auth.signInWithPassword(email:email.text.trim(),password:password.text);
      }
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(signup?'Account created. Check email if confirmation is enabled.':'Welcome back.')));
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString()))); }
    if(mounted)setState(()=>busy=false);
  }
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:ListView(padding:const EdgeInsets.all(24),children:[
    const SizedBox(height:45), const Text('BEAUTYBOOK',style:TextStyle(fontSize:32,fontWeight:FontWeight.w900)),
    Text(signup?'Create your account':'Beauty • Fashion • Your Style',style:const TextStyle(color:Colors.black54)),
    const SizedBox(height:30),
    if(signup) TextField(controller:name,decoration:const InputDecoration(labelText:'Full name',border:OutlineInputBorder())),
    if(signup) const SizedBox(height:12),
    TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',border:OutlineInputBorder())),
    const SizedBox(height:12),
    TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Password',border:OutlineInputBorder())),
    const SizedBox(height:18),
    FilledButton(onPressed:busy?null:submit,child:Text(busy?'Please wait...':signup?'Create account':'Sign in')),
    TextButton(onPressed:()=>setState(()=>signup=!signup),child:Text(signup?'Already have an account? Sign in':'New to BEAUTYBOOK? Create account'))
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
          items:sv.map((x)=>DropdownMenuItem<Map>(value:x,child:Text('${x['name']} • ${x['price_cfa']} CFA'))).toList(),onChanged:(v)=>setState(()=>selected=v)),
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
  Future<void> order()async{
    final phone=(p['businesses']?['whatsapp']??'').toString().replaceAll(RegExp(r'[^0-9]'),'');
    if(phone.isEmpty)return;
    final u=Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent("Hello, I found ${p['name']} on BEAUTYBOOK. Is it available?")}');
    await launchUrl(u,mode:LaunchMode.externalApplication);
  }
  Future<void> fav(BuildContext context)async{
    try{await db.from('favorites').insert({'user_id':db.auth.currentUser!.id,'product_id':p['id']}); if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Added to favorites.')));}
    catch(_){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Already saved or unable to save.')));}
  }
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(12),child:p['image_url']!=null?Image.network(p['image_url'],width:double.infinity,fit:BoxFit.cover):Container(color:const Color(0xfff7e6ed),child:const Center(child:Icon(Icons.checkroom,size:55))))),
    const SizedBox(height:8),Text(p['name'],maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold)),
    Text('${p['price_cfa']} CFA',style:const TextStyle(color:Color(0xff8e4162),fontWeight:FontWeight.bold)),
    Row(children:[IconButton(onPressed:()=>fav(context),icon:const Icon(Icons.favorite_border)),Expanded(child:FilledButton(onPressed:order,child:const Text('Order')))])
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
  final name=TextEditingController(),price=TextEditingController(),stock=TextEditingController(); String category='clothing'; XFile? photo; bool busy=false;
  Future<Map?> myBusiness() async {
    final x = await db.from('businesses').select().eq('owner_id', db.auth.currentUser!.id).limit(1);
    return x.isEmpty ? null : Map<String,dynamic>.from(x.first);
  }
  Future<void> onboard() async {
    await db.from('businesses').insert({'owner_id':db.auth.currentUser!.id,'name':'My BEAUTYBOOK Business','business_type':'both','category':'beauty','location':'Lomé, Togo','verified':false});
    await db.from('profiles').update({'role':'seller'}).eq('id',db.auth.currentUser!.id);
    if(mounted) setState((){});
  }
  Future<void> add()async{
    final b=await myBusiness(); if(b==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Create your BEAUTYBOOK business first using the button below.')));return;}
    setState(()=>busy=true);
    try{
      String? url;
      if(photo!=null){
        final ext=photo!.name.split('.').last; final path='${db.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await db.storage.from('product-images').upload(path,File(photo!.path));
        url=db.storage.from('product-images').getPublicUrl(path);
      }
      await db.from('products').insert({'business_id':b['id'],'name':name.text.trim(),'category':category,'price_cfa':int.parse(price.text),'stock':int.parse(stock.text),'image_url':url});
      name.clear();price.clear();stock.clear();photo=null;if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Product published.')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
    if(mounted)setState(()=>busy=false);
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    const Text('Seller Studio',style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),const Text('Add clothing, wigs, shoes, bags and beauty products.'),const SizedBox(height:10),
    FutureBuilder<Map?>(future:myBusiness(),builder:(context,s)=>s.connectionState!=ConnectionState.done?const LinearProgressIndicator():s.data==null?FilledButton.icon(onPressed:onboard,icon:const Icon(Icons.storefront),label:const Text('Create my BEAUTYBOOK business')):Card(child:ListTile(leading:const Icon(Icons.verified_user_outlined),title:Text(s.data!['name']??'Business'),subtitle:const Text('Business profile active')))),const SizedBox(height:18),
    TextField(controller:name,decoration:const InputDecoration(labelText:'Product name',border:OutlineInputBorder())),const SizedBox(height:10),
    DropdownButtonFormField(value:category,decoration:const InputDecoration(labelText:'Category',border:OutlineInputBorder()),items:['clothing','wigs','shoes','bags','accessories','beauty products'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v!)),
    const SizedBox(height:10),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Price (CFA)',border:OutlineInputBorder())),const SizedBox(height:10),
    TextField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Stock quantity',border:OutlineInputBorder())),const SizedBox(height:12),
    OutlinedButton.icon(onPressed:()async{final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:80);if(x!=null)setState(()=>photo=x);},icon:const Icon(Icons.image),label:Text(photo==null?'Choose product photo':'Photo selected')),
    FilledButton(onPressed:busy?null:add,child:Text(busy?'Publishing...':'Publish product'))
  ]);
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
