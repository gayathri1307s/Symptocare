
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';
import '../widgets/symptocare_logo.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
const SignupScreen({super.key});

@override
State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
final _formKey = GlobalKey<FormState>();
final _nameController = TextEditingController();
final _emailController = TextEditingController();
final _passwordController = TextEditingController();
final _confirmPasswordController = TextEditingController();

bool _obscurePassword = true;
bool _obscureConfirmPassword = true;
bool _isLoading = false;

Future<void> _createAccount() async {
if (!_formKey.currentState!.validate()) return;

setState(() => _isLoading = true);

try {
final credential = await FirebaseAuth.instance
    .createUserWithEmailAndPassword(
email: _emailController.text.trim(),
password: _passwordController.text,
);

await credential.user?.updateDisplayName(
_nameController.text.trim(),
);

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Account created successfully!'),
),
);

Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) => const LoginScreen(),
),
);
} on FirebaseAuthException catch (e) {
if (!mounted) return;

String message;

switch (e.code) {
case 'email-already-in-use':
message = 'An account already exists with this email.';
break;
case 'invalid-email':
message = 'Please enter a valid email address.';
break;
case 'weak-password':
message = 'Your password is too weak.';
break;
case 'network-request-failed':
message = 'Network error. Please check your internet.';
break;
case 'operation-not-allowed':
message = 'Email/password sign-up is not enabled in Firebase.';
break;
default:
message = e.message ?? 'Could not create your account.';
}

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message)),
);
} catch (_) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Something went wrong. Please try again.'),
),
);
} finally {
if (mounted) {
setState(() => _isLoading = false);
}
}
}

@override
void dispose() {
_nameController.dispose();
_emailController.dispose();
_passwordController.dispose();
_confirmPasswordController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFFF8FAFF),
body: SafeArea(
child: Center(
child: SingleChildScrollView(
padding: const EdgeInsets.symmetric(
horizontal: 28,
vertical: 20,
),
child: Form(
key: _formKey,
  autovalidateMode: AutovalidateMode.onUserInteraction,
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
const Center(
child: SymptoCareLogo(size: 64),
),
const SizedBox(height: 16),

const Text(
'Create Account',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 28,
fontWeight: FontWeight.bold,
color: AppTheme.primaryBlue,
),
),
const SizedBox(height: 8),

const Text(
'Join SymptoCare to understand your health better',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 14,
color: AppTheme.textGrey,
),
),
const SizedBox(height: 28),

const Text(
'Full Name',
style: TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 8),

TextFormField(
controller: _nameController,
textCapitalization: TextCapitalization.words,
decoration: _inputDecoration(
hint: 'Enter your full name',
icon: Icons.person_outline_rounded,
),
validator: (value) {
if (value == null || value.trim().isEmpty) {
return 'Please enter your name';
}
return null;
},
),
const SizedBox(height: 16),

const Text(
'Email Address',
style: TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 8),

TextFormField(
controller: _emailController,
keyboardType: TextInputType.emailAddress,
decoration: _inputDecoration(
hint: 'Enter your email',
icon: Icons.email_outlined,
),
validator: (value) {
if (value == null || value.trim().isEmpty) {
return 'Please enter your email';
}
if (!RegExp(
r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
).hasMatch(value.trim())) {
return 'Please enter a valid email';
}
return null;
},
),
const SizedBox(height: 16),

const Text(
'Password',
style: TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 8),

TextFormField(
controller: _passwordController,
obscureText: _obscurePassword,
decoration: _inputDecoration(
hint: 'Create a password',
icon: Icons.lock_outline_rounded,
).copyWith(
suffixIcon: IconButton(
icon: Icon(
_obscurePassword
? Icons.visibility_off_outlined
    : Icons.visibility_outlined,
),
onPressed: () {
setState(() {
_obscurePassword = !_obscurePassword;
});
},
),
),
  validator: (value) {
final password = value ?? '';
final errors = <String>[];

if (password.isEmpty) {
errors.add('Please create a password');
} else {
if (password.length < 8) {
errors.add('Use at least 8 characters');
}
if (!RegExp(r'[A-Z]').hasMatch(password)) {
errors.add('Include an uppercase letter');
}
if (!RegExp(r'[a-z]').hasMatch(password)) {
errors.add('Include a lowercase letter');
}
if (!RegExp(r'[0-9]').hasMatch(password)) {
errors.add('Include a number');
}
if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
errors.add('Include a special character');
}
}

return errors.isEmpty ? null : errors.join('\n');
},
),
const SizedBox(height: 16),

const Text(
'Confirm Password',
style: TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 8),

TextFormField(
controller: _confirmPasswordController,
obscureText: _obscureConfirmPassword,
decoration: _inputDecoration(
hint: 'Re-enter your password',
icon: Icons.lock_outline_rounded,
).copyWith(
suffixIcon: IconButton(
icon: Icon(
_obscureConfirmPassword
? Icons.visibility_off_outlined
    : Icons.visibility_outlined,
),
onPressed: () {
setState(() {
_obscureConfirmPassword =
!_obscureConfirmPassword;
});
},
),
),
validator: (value) {
if (value == null || value.isEmpty) {
return 'Please confirm your password';
}
if (value != _passwordController.text) {
return 'Passwords do not match';
}
return null;
},
),

const SizedBox(height: 26),

SizedBox(
height: 54,
child: ElevatedButton(
onPressed: _isLoading ? null : _createAccount,
style: ElevatedButton.styleFrom(
backgroundColor: AppTheme.primaryBlue,
foregroundColor: Colors.white,
elevation: 2,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
),
child: _isLoading
? const SizedBox(
height: 22,
width: 22,
child: CircularProgressIndicator(
strokeWidth: 2,
color: Colors.white,
),
)
    : const Text(
'Create Account',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
),
),

const SizedBox(height: 20),

Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Flexible(
child: Text(
'Already have an account? ',
style: TextStyle(
color: AppTheme.textGrey,
),
),
),
TextButton(
onPressed: _isLoading
? null
    : () {
Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) => const LoginScreen(),
),
);
},
child: const Text(
'Sign In',
style: TextStyle(
fontWeight: FontWeight.bold,
),
),
),
],
),
],
),
),
),
),
),
);
}

InputDecoration _inputDecoration({
required String hint,
required IconData icon,
}) {
return InputDecoration(
hintText: hint,
prefixIcon: Icon(
icon,
color: AppTheme.primaryBlue,
),
filled: true,
fillColor: Colors.white,
contentPadding: const EdgeInsets.symmetric(
horizontal: 16,
vertical: 16,
),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(14),
borderSide: const BorderSide(
color: Color(0xFFDCE5F5),
),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(14),
borderSide: const BorderSide(
color: Color(0xFFDCE5F5),
),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(14),
borderSide: const BorderSide(
color: AppTheme.primaryBlue,
width: 1.5,
),
),
);
}
}
