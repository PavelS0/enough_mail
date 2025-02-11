import 'dart:io';

import 'package:enough_mail/enough_mail.dart';

String userName = 'user.name';
String password = 'password';
String domain = 'domain.com';
String imapServerHost = 'imap.$domain';
int imapServerPort = 993;
bool isImapServerSecure = true;
String popServerHost = 'pop.$domain';
int popServerPort = 995;
bool isPopServerSecure = true;
String smtpServerHost = 'smtp.$domain';
int smtpServerPort = 465;
bool isSmtpServerSecure = true;

// ignore: avoid_void_async
void main() async {
  //await mailExample();
  await discoverExample();
  await imapExample();
  await smtpExample();
  await popExample();
  exit(0);
}

/// Auto discover settings from email address example
Future<void> discoverExample() async {
  const email = 'someone@enough.de';
  final config = await Discover.discover(email, isLogEnabled: false);
  if (config == null) {
    print('Unable to discover settings for $email');
  } else {
    print('Settings for $email:');
    for (final provider in config.emailProviders!) {
      print('provider: ${provider.displayName}');
      print('provider-domains: ${provider.domains}');
      print('documentation-url: ${provider.documentationUrl}');
      print('Incoming:');
      provider.incomingServers?.forEach(print);
      print(provider.preferredIncomingServer);
      print('Outgoing:');
      provider.outgoingServers?.forEach(print);
      print(provider.preferredOutgoingServer);
    }
  }
}

/// High level mail API example
Future<void> mailExample() async {
  final email = '$userName@$domain';
  print('discovering settings for  $email...');
  final config = await Discover.discover(email);
  if (config == null) {
    // note that you can also directly create an account when
    // you cannot autodiscover the settings:
    // Compare the [MailAccount.fromManualSettings]
    // and [MailAccount.fromManualSettingsWithAuth]
    // methods for details.
    print('Unable to autodiscover settings for $email');
    return;
  }
  print('connecting to ${config.displayName}.');
  final account =
      MailAccount.fromDiscoveredSettings('my account', email, password, config);
  final mailClient = MailClient(account, isLogEnabled: true);
  try {
    await mailClient.connect();
    print('connected');
    final mailboxes =
        await mailClient.listMailboxesAsTree(createIntermediate: false);
    print(mailboxes);
    await mailClient.selectInbox();
    final messages = await mailClient.fetchMessages(count: 20);
    messages.forEach(printMessage);
    mailClient.eventBus.on<MailLoadEvent>().listen((event) {
      print('New message at ${DateTime.now()}:');
      printMessage(event.message);
    });
    await mailClient.startPolling();
  } on MailException catch (e) {
    print('High level API failed with $e');
  }
}

/// Low level IMAP API usage example
Future<void> imapExample() async {
  final client = ImapClient(isLogEnabled: false);
  try {
    await client.connectToServer(imapServerHost, imapServerPort,
        isSecure: isImapServerSecure);
    await client.login(userName, password);
    final mailboxes = await client.listMailboxes();
    print('mailboxes: $mailboxes');
    await client.selectInbox();
    // fetch 10 most recent messages:
    final fetchResult = await client.fetchRecentMessages(
        messageCount: 10, criteria: 'BODY.PEEK[]');
    fetchResult.messages.forEach(printMessage);
    await client.logout();
  } on ImapException catch (e) {
    print('IMAP failed with $e');
  }
}

/// Low level SMTP API example
Future<void> smtpExample() async {
  final client = SmtpClient('enough.de', isLogEnabled: true);
  try {
    await client.connectToServer(smtpServerHost, smtpServerPort,
        isSecure: isSmtpServerSecure);
    await client.ehlo();
    if (client.serverInfo.supportsAuth(AuthMechanism.plain)) {
      await client.authenticate('user.name', 'password', AuthMechanism.plain);
    } else if (client.serverInfo.supportsAuth(AuthMechanism.login)) {
      await client.authenticate('user.name', 'password', AuthMechanism.login);
    } else {
      return;
    }
    final builder = MessageBuilder.prepareMultipartAlternativeMessage()
      ..from = [MailAddress('My name', 'sender@domain.com')]
      ..to = [MailAddress('Your name', 'recipient@domain.com')]
      ..subject = 'My first message'
      ..addTextPlain('hello world.')
      ..addTextHtml('<p>hello <b>world</b></p>');
    final mimeMessage = builder.buildMimeMessage();
    final sendResponse = await client.sendMessage(mimeMessage);
    print('message sent: ${sendResponse.isOkStatus}');
  } on SmtpException catch (e) {
    print('SMTP failed with $e');
  }
}

/// Low level POP3 API example
Future<void> popExample() async {
  final client = PopClient(isLogEnabled: false);
  try {
    await client.connectToServer(popServerHost, popServerPort,
        isSecure: isPopServerSecure);
    await client.login(userName, password);
    // alternative login:
    // await client.loginWithApop(userName, password);
    final status = await client.status();
    print('status: messages count=${status.numberOfMessages}, '
        'messages size=${status.totalSizeInBytes}');
    final messageList = await client.list(status.numberOfMessages);
    print('last message: id=${messageList.first.id} '
        'size=${messageList.first.sizeInBytes}');
    var message = await client.retrieve(status.numberOfMessages);
    printMessage(message);
    message = await client.retrieve(status.numberOfMessages + 1);
    print('trying to retrieve newer message succeeded');
    await client.quit();
  } on PopException catch (e) {
    print('POP failed with $e');
  }
}

void printMessage(MimeMessage message) {
  print('from: ${message.from} with subject "${message.decodeSubject()}"');
  if (!message.isTextPlainMessage()) {
    print(' content-type: ${message.mediaType}');
  } else {
    final plainText = message.decodeTextPlainPart();
    if (plainText != null) {
      final lines = plainText.split('\r\n');
      for (final line in lines) {
        if (line.startsWith('>')) {
          // break when quoted text starts
          break;
        }
        print(line);
      }
    }
  }
}
