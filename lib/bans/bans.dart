import 'dart:developer';

import 'package:civgen/models.dart';
import 'package:civgen/shared/grid.dart';
import 'package:civgen/shared/header.dart';
import 'package:civgen/shared/snake.dart';
import 'package:civgen/shared/submit_button.dart';
import 'package:civgen/shared/timer.dart';
import 'package:civgen/styles.dart';
import 'package:flutter/material.dart';
import 'package:civgen/globals.dart';
import 'package:provider/provider.dart';

class BansPage extends StatefulWidget {
  const BansPage({super.key});

  @override
  State<BansPage> createState() => _BansPageState();
}

// TODO: Setup the same timer setup as the picks page
class _BansPageState extends State<BansPage> {
  bool loaded = false;
  String? highlightedCivLeaderName;
  Map<String, CivStatus> civStatus = {};
  Map<int, String> playerNames = {};
  late SnakeDraft snakeDraft;

  // Represent if any chip is focused
  bool chipFocused = false;

  // Timer in the header
  TimerWidget? timerWidget;

  // Hack to get to the next page
  late Function nextPage;

  // Init function
  @override
  void initState() {
    super.initState();

    log("First time building the bans page, generating all the chips...");
    civMap.forEach((key, _) {
      civStatus[key] = CivStatus.available;
    });

    log("Resetting the timer...");
    resetTimer();
  }

  // Keep track of which chips are pressed
  void onChipPressed(String leaderName) {
    log("Toggling the ban for $leaderName, no longer highlighting $highlightedCivLeaderName");
    setState(() {
      // First update the previous highlighted chip
      if (highlightedCivLeaderName != null) {
        civStatus[highlightedCivLeaderName!] = CivStatus.available;
      }

      highlightedCivLeaderName = leaderName;

      // Then update the new highlighted chip
      civStatus[leaderName] = CivStatus.selected;
    });
  }

  void onSubmitPressed() {
    if (highlightedCivLeaderName == null) {
      throw Exception("No civ is highlighted, submit button shouldn't be visible!");
    }

    // Update the highlighted chip to be locked
    setState(() {
      civStatus[highlightedCivLeaderName!] = CivStatus.banned;
    });

    highlightedCivLeaderName = null;
    advanceToNextPlayer();
  }

  void resetTimer() {
    // TODO: Fetch the timer from the context and make it configurable
    timerWidget = TimerWidget(
        durationSeconds: 120,
        onTimerExpired: () {
          log("Timer expired, moving to the next player");
          advanceToNextPlayer();
        });
    log("Timer reset...");
  }

  void advanceToNextPlayer() {
    log("Advancing to the next player, current player: ${snakeDraft.activePlayer}");

    // Reset the timer
    resetTimer();

    setState(() {
      snakeDraft.advance();
    });

    // If there are no more bans to be made, move to the next page
    //  aka - the last player just drafted
    if (snakeDraft.isDone) {
      log("No more bans to be made, moving to the next page");

      // Also store the bans
      log("Storing the bans in the draft configuration...");
      List<String> bannedCivs =
          civStatus.entries.where((entry) => entry.value == CivStatus.banned).map((entry) => entry.key).toList();
      context.read<DraftConfiguration>().setBans(bannedCivs);

      nextPage(VisiblePage.picks);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    // If the player names is empty, get the number of players from the DraftConfiguration
    // TODO: move this setup to initState - you can't have context there though so you have to do some hacking with a future
    if (!loaded) {
      log("First time building the bans page, generating the player names and order...");

      int numPlayers = context.select<DraftConfiguration, int>((conf) => conf.setupPlayers.value);
      log("Number of players: $numPlayers");

      for (int i = 0; i < numPlayers; i++) {
        playerNames[i] = "Player ${i + 1}";
      }

      int numBansPerPlayer = context.select<DraftConfiguration, int>((conf) => conf.setupBans.value);
      log("Each player can ban $numBansPerPlayer civs");

      snakeDraft = SnakeDraft(numPlayers, numBansPerPlayer);
      log("Player order: $snakeDraft");

      log("First time building the bans page, getting the next page function...");
      nextPage = context.select<DraftConfiguration, Function>((conf) => conf.setActivePage);

      loaded = true;
    }

    return MaterialApp(
      title: 'Banning',
      home: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: headerBar(playerNames[snakeDraft.activePlayer]!, "Banning phase", timerWidget!),
        body: Center(
          child: FractionallySizedBox(
              widthFactor: .6,
              child: CivGrid(
                civStatuses: civStatus,
                onChipPressed: onChipPressed,
              )),
        ),
        floatingActionButton: AnimatedFloatingSubmitButton(
          text: "Confirm Ban",
          onPressed: onSubmitPressed,
          opacityFunction: () => (highlightedCivLeaderName == null ? 0.0 : 1.0),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}
