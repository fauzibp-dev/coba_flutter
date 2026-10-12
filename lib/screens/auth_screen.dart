import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/commerce_repository.dart';
import '../services/shop_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_register) {
        final active = await ShopRepository.instance.signUp(_name.text, _email.text, _password.text);
        if (!mounted) return;
        if (active) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akun dibuat. Cek email untuk konfirmasi, lalu masuk.')));
          setState(() => _register = false);
        }
      } else {
        await ShopRepository.instance.signIn(_email.text, _password.text);
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.primaryDark));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = TextEditingController(text: _email.text.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Masukkan email akun. KKMP Kerten akan meminta Supabase Auth mengirim link pemulihan password.'),
          const SizedBox(height: 12),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, autofocus: true, decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, email.text.contains('@')), child: const Text('Kirim Link')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await CommerceRepository.instance.sendPasswordReset(email.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link reset password dikirim ke ${email.text.trim()}.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    email.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Image.asset('assets/branding/kkmp_kerten_logo.png', height: 126, fit: BoxFit.contain),
                    const SizedBox(height: 8),
                    const Text('Belanja Lebih Mudah Di KKMP Kerten', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 14),
                    Text(_register ? 'Buat akun KKMP Kerten' : 'Masuk ke KKMP Kerten', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(_register ? 'Belanja produk koperasi dengan akunmu.' : 'Masuk untuk keranjang, checkout, pesanan, dan layanan pelanggan.', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, height: 1.4)),
                    const SizedBox(height: 26),
                    if (_register) ...[
                      TextFormField(controller: _name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Nama lengkap'), validator: (v) => (v == null || v.trim().length < 2) ? 'Masukkan nama lengkap.' : null),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Email'), validator: (v) { final value = v?.trim() ?? ''; return (!value.contains('@') || !value.contains('.')) ? 'Email tidak valid.' : null; }),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
                      validator: (v) => (v ?? '').length < 8 ? 'Password minimal 8 karakter.' : null,
                    ),
                    if (!_register) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _loading ? null : _forgotPassword, child: const Text('Lupa password?'))),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _loading ? null : _submit, child: Text(_loading ? 'Memproses...' : (_register ? 'Daftar' : 'Masuk'))),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _loading ? null : () => setState(() => _register = !_register), child: Text(_register ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar')),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
