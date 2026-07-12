import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'services.dart';
import 'ui_components.dart';
import 'journaling_screen.dart';
import 'recommendations_screen.dart';
import 'risk_trends_screen.dart';
import 'happy_corner_screen.dart';

import 'insights_tab.dart';
import 'checkin_tab.dart';
import 'profile_tab.dart';
import 'edit_profile_screen.dart';

class MainDashboard extends StatefulWidget {
  final UserProfile userProfile;
  final int initialIndex;

  const MainDashboard({
    super.key,
    required this.userProfile,
    this.initialIndex = 0,
  });

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final MockSentimentService _sentimentService = MockSentimentService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  late int _selectedIndex;

  List<JournalEntry> _entries = [];
  List<DomainScore> _lastDetectedIssues = [];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final uid = widget.userProfile.userId;
    final entries = await _sentimentService.getAllEntries(uid);
    setState(() {
      _entries = entries;
    });
  }

  Future<void> _openJournalingScreen(DateTime date) async {
    final uid = widget.userProfile.userId;
    final existingEntry = await _sentimentService.getEntry(uid, date);

    final entry = await Navigator.of(context).push<JournalEntry>(
      MaterialPageRoute(
        builder: (context) =>
            JournalingScreen(date: date, initialEntry: existingEntry),
      ),
    );

    if (entry != null) {
      await _sentimentService.saveEntry(uid, entry);
      await _loadEntries();

      setState(() {
        _selectedDay = entry.date;
        _focusedDay = entry.date;
      });
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: _selectedIndex == 0
        ? AppBar(
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/mind_gauge_logo.jpg',
                    height: 36,
                    width: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'MINDGAUGE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.account_circle, size: 32),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(
                        userProfile: widget.userProfile,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          )
        : null,

    body: IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomeTab(),
        const HappyCornerScreen(),
        CheckInTab(
          userProfile: widget.userProfile,
          onCheckInComplete: (results) {
            setState(() {
              _lastDetectedIssues = results;
              _selectedIndex = 3;
            });
          },
        ),
        const InsightsTab(),
        ProfileTab(userProfile: widget.userProfile),
      ],
    ),

    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.background,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.secondary.withOpacity(0.5),
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome),
          label: 'Moments',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.health_and_safety),
          label: 'Check-In',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.insights),
          label: 'Insights',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.support_agent),
          label: 'Support',
        ),
      ],
    ),

    floatingActionButton: _selectedIndex == 0
        ? FloatingActionButton(
            onPressed: () => _openJournalingScreen(DateTime.now()),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          )
        : null,
  );
}

  Widget _buildHomeTab() {
    final JournalEntry? currentEntry = _entries
        .where((e) => e.date.isSameDay(_selectedDay))
        .cast<JournalEntry?>()
        .firstOrNull;

    return SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 24.0, bottom: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CALENDAR SECTION ---
            const Text(
              'CALENDAR',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 10),
            SentimentCalendar(
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              journalEntries: _entries,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPreviousMonth: _goToPreviousMonth,
              onNextMonth: _goToNextMonth,
            ),

            // --- JOURNAL SNIPPET SECTION ---
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Thought Flow',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.calendar_month,
                      color: AppColors.secondary.withOpacity(0.7),
                    ),
                  ],
                ),
                Text(
                  '${_selectedDay.day}/${_selectedDay.month}',
                  style: const TextStyle(fontSize: 16, color: AppColors.text),
                ),
              ],
            ),
            const SizedBox(height: 10),
            JournalSnippetCard(
              entry: currentEntry,
              selectedDate: _selectedDay,
              onTap: () => _openJournalingScreen(_selectedDay),
            ),
            const SizedBox(height: 30),
            const SizedBox(height: 50),
          ],
        ),
      );
  }

  void _goToPreviousMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
      _selectedDay = _focusedDay;
    });
  }

  void _goToNextMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
      _selectedDay = _focusedDay;
    });
  }
}

class SentimentCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<JournalEntry> journalEntries;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const SentimentCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.journalEntries,
    required this.onDaySelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(
      focusedDay.year,
      focusedDay.month,
    );

    final firstDayOfWeek =
        DateTime(focusedDay.year, focusedDay.month, 1).weekday % 7;

    const List<String> weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    final Map<int, String> emojiMap = {
      for (var entry in journalEntries.where(
        (e) =>
            e.date.year == focusedDay.year && e.date.month == focusedDay.month,
      ))
        entry.date.day: entry.sentiment.emoji,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_monthName(focusedDay.month)}, ${focusedDay.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Row(
                  children: [
                    GestureDetector(
                      onTap: onPreviousMonth,
                      child: const Icon(
                        Icons.arrow_drop_up,
                        color: AppColors.secondary,
                        size: 28,
                      ),
                    ),
                    GestureDetector(
                      onTap: onNextMonth,
                      child: const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.secondary,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(thickness: 1, height: 10),

          // Weekday Headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4.0,
              crossAxisSpacing: 4.0,
              childAspectRatio: 0.8,
            ),
            itemCount: daysInMonth + firstDayOfWeek,
            itemBuilder: (context, index) {
              if (index < firstDayOfWeek) {
                return Container();
              }

              final dayOfMonth = index - firstDayOfWeek + 1;
              final date = DateTime(
                focusedDay.year,
                focusedDay.month,
                dayOfMonth,
              );
              final isSelected = date.isSameDay(selectedDay);
              final emoji = emojiMap[dayOfMonth] ?? '';

              return GestureDetector(
                onTap: () => onDaySelected(date, focusedDay),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      child: Text(
                        '$dayOfMonth',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.text,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (emoji.isNotEmpty)
                      SizedBox(
                        height: 14,
                        width: 25,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _monthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month - 1];
}

class JournalSnippetCard extends StatelessWidget {
  final JournalEntry? entry;
  final DateTime selectedDate;
  final VoidCallback onTap;

  const JournalSnippetCard({
    super.key,
    required this.entry,
    required this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasEntry = entry != null;

    final String snippetText = hasEntry
        ? entry!.text
        : selectedDate.isSameDay(DateTime.now())
        ? 'Tap to write your thoughts for today.'
        : 'No journal entry for this date.';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(15),
          border: hasEntry
              ? Border.all(color: AppColors.secondary.withOpacity(0.3))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasEntry)
              Text(
                'Sentiment: ${entry!.sentiment.emoji} ${entry!.sentiment.description}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: entry!.sentiment.score < 0
                      ? AppColors.danger
                      : AppColors.primary,
                ),
              ),
            if (hasEntry) const SizedBox(height: 8),
            Text(
              snippetText,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                color: hasEntry
                    ? AppColors.text
                    : AppColors.secondary.withOpacity(0.7),
                fontStyle: hasEntry ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


