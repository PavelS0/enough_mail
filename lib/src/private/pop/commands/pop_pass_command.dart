import 'package:enough_mail/src/private/pop/pop_command.dart';

class PopPassCommand extends PopCommand<String> {
  PopPassCommand(String pass) : super('PASS $pass');

  @override
  String toString() {
    return 'PASS <password scrambled>';
  }
}
