import 'package:enough_mail/src/imap/message_sequence.dart';
import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/response_parser.dart';

import 'imap_response.dart';

/// Parses sort responses
class SortParser extends ResponseParser<SortImapResult> {
  final bool isUidSort;
  var ids = <int>[];
  int? highestModSequence;

  bool isExtended;
  // Reference tag for the current extended sort untagged response
  String? tag;
  int? min;
  int? max;
  int? count;

  String? partialRange;

  SortParser([this.isUidSort = false, this.isExtended = false]);

  @override
  SortImapResult? parse(
      ImapResponse details, Response<SortImapResult> response) {
    if (response.isOkStatus) {
      final result = SortImapResult()
        ..matchingSequence = MessageSequence.fromIds(ids, isUid: isUidSort)
        ..highestModSequence = highestModSequence
        ..isExtended = isExtended
        ..tag = tag
        ..min = min
        ..max = max
        ..count = count
        ..partialRange = partialRange;
      return result;
    }
    return null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<SortImapResult>? response) {
    final details = imapResponse.parseText;
    if (details.startsWith('SORT ')) {
      return _parseSimpleDetails(details);
    } else if (details.startsWith('ESEARCH ')) {
      return _parseExtendedDetails(details);
    } else if (details == 'SORT' || details == 'ESEARCH') {
      // this is an empty search result
      return true;
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }

  bool _parseSimpleDetails(String details) {
    final listEntries = parseListEntries(details, 'SORT '.length, null);
    if (listEntries == null) {
      return false;
    }
    for (var i = 0; i < listEntries.length; i++) {
      final entry = listEntries[i];
      // Maybe MODSEQ should not be supported by SORT (introduced by ESORT?)
      if (entry == '(MODSEQ') {
        i++;
        final modSeqText =
            listEntries[i].substring(0, listEntries[i].length - 1);
        highestModSequence = int.tryParse(modSeqText);
      } else {
        final id = int.tryParse(entry);
        if (id != null) {
          ids.add(id);
        }
      }
    }
    return true;
  }

  bool _parseExtendedDetails(String details) {
    final listEntries = parseListEntries(details, 'ESEARCH '.length, null);
    if (listEntries == null) {
      return false;
    }
    for (var i = 0; i < listEntries.length; i++) {
      final entry = listEntries[i];
      if (entry == '(TAG') {
        i++;
        tag = listEntries[i].substring(1, listEntries[i].length - 2);
      } else if (entry == 'UID') {
        // Inclided for completeness.
      } else if (entry == 'MIN') {
        i++;
        min = int.tryParse(listEntries[i]);
      } else if (entry == 'MAX') {
        i++;
        max = int.tryParse(listEntries[i]);
      } else if (entry == 'COUNT') {
        i++;
        count = int.tryParse(listEntries[i]);
      } else if (entry == 'ALL') {
        i++;
        final seq =
            MessageSequence.parse(listEntries[i], isUidSequence: isUidSort);
        if (!seq.isNil) {
          ids = seq.toList();
        }
      } else if (entry == 'MODSEQ') {
        i++;
        highestModSequence = int.tryParse(listEntries[i]);
      } else if (entry == 'PARTIAL') {
        i++;
        partialRange = listEntries[i].substring(1);
        i++;
        final seq = MessageSequence.parse(
            listEntries[i].substring(0, listEntries[i].length - 1),
            isUidSequence: isUidSort);
        if (!seq.isNil) {
          ids = seq.toList();
        }
      }
    }
    return true;
  }
}
