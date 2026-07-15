import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseUserService _userService = FirebaseUserService();

  // --- LOGIN WITH FIREBASE AUTH ---
  Future<UserProfile?> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        final userData = await _userService.getUserDetails(user.uid);

        if (userData != null) {
          return UserProfile.fromDatabase(userData, user);
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw 'An unknown error occurred.';
    }
  }

  // --- REGISTER WITH FIREBASE AUTH ---
  Future<UserProfile> register({
    required String email,
    required String password,
    required String name,
    required DateTime birthDate,
    required String location,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;

      await _userService.saveUserDetails(user.uid, name, birthDate, location, []);

      return UserProfile(
        email: email,
        name: name,
        userId: user.uid,
        birthDate: birthDate,
        location: location,
        interests: [],
        photos: [],
      );
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw 'An unknown error occurred.';
    }
  }

  // --- DELETE ACCOUNT ---
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // First delete from Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        // Then delete the auth user
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Security restriction: Please log out and log back in before deleting your account.';
      }
      throw e.message ?? 'An unknown error occurred.';
    } catch (e) {
      throw 'Failed to delete account: $e';
    }
  }

  // --- RESET PASSWORD ---
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An unknown error occurred.';
    }
  }

  // --- LOGOUT ---
  Future<void> logout() async {
    await _auth.signOut();
  }
}

class FirebaseUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUserDetails(
    String userId,
    String name,
    DateTime birthDate,
    String location,
    List<String>? interests,
  ) async {
    final data = {
      'name': name,
      'birthDate': Timestamp.fromDate(birthDate),
      'location': location,
    };
    if (interests != null) {
      data['interests'] = interests;
    }
    await _firestore
        .collection('users')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> saveInterests(String userId, List<String> interests) async {
    await _firestore.collection('users').doc(userId).set({
      'interests': interests,
    }, SetOptions(merge: true));
  }

  Future<void> savePhotos(String userId, List<String> photos) async {
    await _firestore.collection('users').doc(userId).set({
      'photos': photos,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> saveAssessmentResults(
    String userId,
    List<DomainScore> results,
    String? overallStatus,
  ) async {
    final assessmentData = {
      'timestamp': FieldValue.serverTimestamp(),
      'clientTimestamp': DateTime.now(),
      'globalDiagnosis': overallStatus, // Store the high-level ML result
      'issues': results
          .map(
            (s) => {
              'domainName': s.domainName,
              'severity': s.mlDiagnosis, // Store categorical ML result
              'score': s.highestScore,
              'followUp': s.Level2AdultMeasure,
            },
          )
          .toList(),
    };

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('assessments')
        .add(assessmentData);
  }

  Future<Map<String, dynamic>?> getLatestAssessment(String userId) async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('assessments')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data();
    }
    return null;
  }

  Future<void> saveLevel2Result({
    required String userId,
    required String domainName,
    required String diagnosis,
    required List<int> scores,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('level2_assessments')
        .add({
          'timestamp': FieldValue.serverTimestamp(),
          'domainName': domainName,
          'diagnosis': diagnosis,
          'scores': scores,
        });
  }
}

class FirestoreJournalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userJournal(String uid) {
    return _firestore.collection('users').doc(uid).collection('journals');
  }

  Future<void> saveEntry(String uid, JournalEntry entry) async {
    final key = '${entry.date.year}-${entry.date.month}-${entry.date.day}';

    await _userJournal(uid).doc(key).set({
      'date': Timestamp.fromDate(entry.date),
      'text': entry.text,
      'emoji': entry.sentiment.emoji,
      'score': entry.sentiment.score,
      'description': entry.sentiment.description,
    });
  }

  Future<List<JournalEntry>> getAllEntries(String uid) async {
    final snapshot = await _userJournal(uid).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return JournalEntry(
        date: (data['date'] as Timestamp).toDate(),
        text: data['text'],
        sentiment: SentimentResult(
          data['emoji'],
          (data['score'] as num).toDouble(),
          data['description'],
        ),
      );
    }).toList();
  }

  Future<JournalEntry?> getEntry(String uid, DateTime date) async {
    final key = '${date.year}-${date.month}-${date.day}';
    final doc = await _userJournal(uid).doc(key).get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    return JournalEntry(
      date: (data['date'] as Timestamp).toDate(),
      text: data['text'],
      sentiment: SentimentResult(
        data['emoji'],
        (data['score'] as num).toDouble(),
        data['description'],
      ),
    );
  }
}

class MockQuestionnaireService {
  static const Map<String, DomainMetadata> _domainThresholds = {
    "I": DomainMetadata(
      "Depression",
      3,
      "LEVEL 2-Depression-Adult (PROMIS Emotional Distress-Depression-Short Form)",
    ),
    "II": DomainMetadata(
      "Anger",
      3,
      "LEVEL 2-Anger-Adult (PROMIS Emotional Distress-Anger-Short Form)",
    ),
    "III": DomainMetadata(
      "Mania",
      3,
      "LEVEL 2-Mania-Adult (Altman Self-Rating Mania Scale)",
    ),
    "IV": DomainMetadata(
      "Anxiety",
      3,
      "LEVEL 2-Anxiety-Adult (PROMIS Emotional Distress-Anxiety-Short Form)",
    ),
    "V": DomainMetadata(
      "Somatic Symptoms",
      3,
      "LEVEL 2-Somatic Symptom-Adult (Patient Health Questionnaire 15 Somatic Symptom Severity [PHQ-15])",
    ),
    "VI": DomainMetadata("Suicidal Ideation", 2, "None"),
    "VII": DomainMetadata("Psychosis", 2, "None"),
    "VIII": DomainMetadata(
      "Sleep Problems",
      3,
      "LEVEL 2-Sleep Disturbance - Adult (PROMIS-Sleep Disturbance-Short Form)",
    ),
    "IX": DomainMetadata("Memory", 3, "None"),
    "X": DomainMetadata(
      "Repetitive Thoughts and Behaviors",
      3,
      "LEVEL 2-Repetitive Thoughts and Behaviors-Adult (adapted from the Florida Obsessive-Compulsive Inventory [FOCI] Severity Scale [Part B])",
    ),
    "XI": DomainMetadata("Dissociation", 3, "None"),
    "XII": DomainMetadata("Personality Functioning", 3, "None"),
    "XIII": DomainMetadata(
      "Substance Use",
      2,
      "LEVEL 2-Substance Abuse-Adult (adapted from the NIDA-modified ASSIST)",
    ),
  };

  static const Map<String, DomainMetadata> _adolescentDomainThresholds = {
    "I": DomainMetadata(
      "Somatic Symptoms",
      3,
      "LEVEL 2—Somatic Symptom—Child Age 11–17",
    ),
    "II": DomainMetadata(
      "Sleep Problems",
      3,
      "LEVEL 2—Sleep Disturbance—Child Age 11–17",
    ),
    "III": DomainMetadata("Inattention", 2, "None"),
    "IV": DomainMetadata("Depression", 3, "LEVEL 2—Depression—Child Age 11–17"),
    "V": DomainMetadata("Anger", 3, "LEVEL 2—Anger—Child Age 11–17"),
    "VI": DomainMetadata(
      "Irritability",
      3,
      "LEVEL 2—Irritability—Child Age 11–17",
    ),
    "VII": DomainMetadata("Mania", 3, "LEVEL 2—Mania—Child Age 11–17"),
    "VIII": DomainMetadata("Anxiety", 3, "LEVEL 2—Anxiety—Child Age 11–17"),
    "IX": DomainMetadata("Psychosis", 2, "None"),
    "X": DomainMetadata(
      "Repetitive Thoughts and Behaviors",
      3,
      "LEVEL 2—Repetitive Thoughts and Behaviors—Child Age 11–17",
    ),
    "XI": DomainMetadata(
      "Substance Use",
      2,
      "LEVEL 2—Substance Use—Child Age 11–17",
    ),
    "XII": DomainMetadata("Suicidal Ideation", 2, "None"),
  };

  static List<QuestionnaireData> getAdultLevel1Questions() {
    return [
      QuestionnaireData(
        "I",
        "1",
        "Little interest or pleasure in doing things?",
      ),
      QuestionnaireData("I", "2", "Feeling down, depressed, or hopeless?"),
      QuestionnaireData(
        "II",
        "3",
        "Feeling more irritated, grouchy, or angry than usual?",
      ),
      QuestionnaireData(
        "III",
        "4",
        "Sleeping less than usual, but still have a lot of energy?",
      ),
      QuestionnaireData(
        "III",
        "5",
        "Starting lots more projects than usual or doing more risky things than usual?",
      ),
      QuestionnaireData(
        "IV",
        "6",
        "Feeling nervous, anxious, frightened, worried, or on edge?",
      ),
      QuestionnaireData("IV", "7", "Feeling panic or being frightened?"),
      QuestionnaireData(
        "IV",
        "8",
        "Avoiding situations that make you anxious?",
      ),
      QuestionnaireData(
        "V",
        "9",
        "Unexplained aches and pains (e.g., head, back, joints, abdomen, legs)?",
      ),
      QuestionnaireData(
        "V",
        "10",
        "Feeling that your illnesses are not being taken seriously enough?",
      ),
      QuestionnaireData("VI", "11", "Thoughts of actually hurting yourself?"),
      QuestionnaireData(
        "VII",
        "12",
        "Hearing things other people couldn't hear, such as voices even when no one was around?",
      ),
      QuestionnaireData(
        "VII",
        "13",
        "Feeling that someone could hear your thoughts, or that you could hear what another person was thinking?",
      ),
      QuestionnaireData(
        "VIII",
        "14",
        "Problems with sleep that affected your sleep quality over all?",
      ),
      QuestionnaireData(
        "IX",
        "15",
        "Problems with memory (e.g., learning new information) or with location (e.g., finding your way home)?",
      ),
      QuestionnaireData(
        "X",
        "16",
        "Unpleasant thoughts, urges, or images that repeatedly enter your mind?",
      ),
      QuestionnaireData(
        "X",
        "17",
        "Feeling driven to perform certain behaviors or mental acts over and over again?",
      ),
      QuestionnaireData(
        "XI",
        "18",
        "Feeling detached or distant from yourself, your body, your physical surroundings, or your memories?",
      ),
      QuestionnaireData(
        "XII",
        "19",
        "Not knowing who you really are or what you want out of life?",
      ),
      QuestionnaireData(
        "XII",
        "20",
        "Not feeling close to other people or enjoying your relationships with them?",
      ),
      QuestionnaireData(
        "XIII",
        "21",
        "Drinking at least 4 drinks of any kind of alcohol in a single day?",
      ),
      QuestionnaireData(
        "XIII",
        "22",
        "Smoking any cigarettes, a cigar, or pipe, or using snuff or chewing tobacco?",
      ),
      QuestionnaireData(
        "XIII",
        "23",
        "Using any of the following medicines on your own, that is, without a doctor's prescription, in greater amounts or longer than prescribed [e.g., painkillers (like Vicodin), stimulants (like Ritalin or Adderall), sedatives or tranquilizers (like sleeping pills or Valium), or drugs like marijuana, cocaine or crack, club drugs (like ecstasy), hallucinogens (like LSD), heroin, inhalants or solvents (like glue), or methamphetamine (like speed)]?",
      ),
    ];
  }

  static List<QuestionnaireData> getAdolescentLevel1Questions() {
    return [
      QuestionnaireData(
        "I",
        "1",
        "Been bothered by stomachaches, headaches, or other aches and pains?",
      ),
      QuestionnaireData(
        "I",
        "2",
        "Worried about your health or about getting sick?",
      ),
      QuestionnaireData(
        "II",
        "3",
        "Been bothered by not being able to fall asleep or stay asleep?",
      ),
      QuestionnaireData(
        "III",
        "4",
        "Been bothered by not being able to pay attention when in class or doing homework?",
      ),
      QuestionnaireData(
        "IV",
        "5",
        "Had less fun doing things than you used to?",
      ),
      QuestionnaireData("IV", "6", "Felt sad or depressed for several hours?"),
      QuestionnaireData(
        "V",
        "7",
        "Felt more irritated or easily annoyed than usual?",
      ),
      QuestionnaireData("VI", "8", "Felt angry or lost your temper?"),
      QuestionnaireData("VII", "9", "Started lots more projects than usual?"),
      QuestionnaireData(
        "VII",
        "10",
        "Slept less than usual but still had a lot of energy?",
      ),
      QuestionnaireData("VIII", "11", "Felt nervous, anxious, or scared?"),
      QuestionnaireData("VIII", "12", "Not been able to stop worrying?"),
      QuestionnaireData(
        "VIII",
        "13",
        "Not been able to do things because they made you feel nervous?",
      ),
      QuestionnaireData(
        "IX",
        "14",
        "Heard voices that no one else could hear?",
      ),
      QuestionnaireData(
        "IX",
        "15",
        "Had visions when you were completely awake?",
      ),
      QuestionnaireData(
        "X",
        "16",
        "Thoughts that you would do something bad or something bad would happen?",
      ),
      QuestionnaireData(
        "X",
        "17",
        "Felt the need to check on things over and over again?",
      ),
      QuestionnaireData(
        "X",
        "18",
        "Worried a lot about things being dirty or having germs?",
      ),
      QuestionnaireData(
        "X",
        "19",
        "Felt you had to do things in a certain way to keep something bad from happening?",
      ),
      QuestionnaireData(
        "XI",
        "20",
        "Had an alcoholic beverage (beer, wine, liquor)?",
      ),
      QuestionnaireData("XI", "21", "Smoked a cigarette, cigar, or pipe?"),
      QuestionnaireData(
        "XI",
        "22",
        "Used drugs like marijuana, cocaine, or club drugs?",
      ),
      QuestionnaireData(
        "XI",
        "23",
        "Used medicine without a doctor's prescription to get high?",
      ),
      QuestionnaireData(
        "XII",
        "24",
        "Thought about killing yourself or committing suicide?",
      ),
      QuestionnaireData("XII", "25", "Have you EVER tried to kill yourself?"),
    ];
  }

  static QuestionnaireType mapAgeToQuestionnaire(int age) {
    if (age >= 18) {
      return QuestionnaireType.adultLevel1;
    } else if (age >= 11) {
      return QuestionnaireType.adolescentLevel1;
    }
    return QuestionnaireType.adultLevel1;
  }

  static List<QuestionnaireData> getLevel1Questions(int age) {
    final type = mapAgeToQuestionnaire(age);
    if (type == QuestionnaireType.adultLevel1) {
      return getAdultLevel1Questions();
    } else if (type == QuestionnaireType.adolescentLevel1) {
      return getAdolescentLevel1Questions();
    }
    return getAdultLevel1Questions();
  }

  Future<List<DomainScore>> submitQuestionnaire(
    List<QuestionnaireData> responses,
    int age,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    final isAdolescent =
        mapAgeToQuestionnaire(age) == QuestionnaireType.adolescentLevel1;
    final thresholdMap = isAdolescent
        ? _adolescentDomainThresholds
        : _domainThresholds;
    final Map<String, int> domainHighestScores = {};

    for (var item in responses) {
      final domain = item.domain;
      final score = item.score.round();

      domainHighestScores[domain] =
          (domainHighestScores[domain] == null ||
              score > domainHighestScores[domain]!)
          ? score
          : domainHighestScores[domain]!;
    }

    final List<DomainScore> results = [];

    domainHighestScores.forEach((domain, highestScore) {
      final metadata = thresholdMap[domain];
      if (metadata == null) return;

      if (highestScore >= metadata.thresholdScore) {
        results.add(
          DomainScore(
            domain,
            metadata.domainName,
            highestScore,
            metadata.thresholdScore,
            metadata.Level2AdultMeasure,
          ),
        );
      }
    });

    results.sort((a, b) => b.highestScore.compareTo(a.highestScore));

    return results;
  }

  static final Map<String, List<Level2AdultQuestionnaireData>>
  _level2AdultQuestions = {
    "Depression": [
      Level2AdultQuestionnaireData("I", "D1", "I felt depressed."),
      Level2AdultQuestionnaireData("I", "D2", "I felt worthless."),
      Level2AdultQuestionnaireData("I", "D3", "I felt sad."),
      Level2AdultQuestionnaireData("I", "D4", "I felt hopeless."),
      Level2AdultQuestionnaireData("I", "D5", "I felt like a failure."),
      Level2AdultQuestionnaireData("I", "D6", "I felt that I have no future."),
      Level2AdultQuestionnaireData("I", "D7", "I felt helpless."),
      Level2AdultQuestionnaireData("I", "D8", "I felt discouraged."),
    ],
    "Anger": [
      Level2AdultQuestionnaireData(
        "II",
        "A1",
        "In the past seven days were you irritated more than people knew?",
      ),
      Level2AdultQuestionnaireData(
        "II",
        "A2",
        "In the past seven days, have you felt angry?",
      ),
      Level2AdultQuestionnaireData(
        "II",
        "A3",
        " In the past seven days, have you felt like you were ready to explode?",
      ),
      Level2AdultQuestionnaireData(
        "II",
        "A4",
        "In the past seven days, were you grouchy?",
      ),
      Level2AdultQuestionnaireData(
        "II",
        "A5",
        "In the past seven days, have you felt annoyed?",
      ),
    ],
    "Mania": [
      Level2AdultQuestionnaireData(
        "III",
        "M1",
        "I feel happier or more cheerful than usual.",
      ),
      Level2AdultQuestionnaireData(
        "III",
        "M2",
        "I feel more self-confident than usual.",
      ),
      Level2AdultQuestionnaireData(
        "III",
        "M3",
        "I need less sleep than usual.",
      ),
      Level2AdultQuestionnaireData("III", "M4", "I talk more than usual."),
      Level2AdultQuestionnaireData(
        "III",
        "M5",
        "I have been more active than usual (socially, sexually, at work, home, or school).",
      ),
    ],
    "Anxiety": [
      Level2AdultQuestionnaireData(
        "IV",
        "AN1",
        "In the past seven days, have you felt fearful?",
      ),
      Level2AdultQuestionnaireData(
        "IV",
        "AN2",
        "In the past seven days, have you felt anxious?",
      ),
      Level2AdultQuestionnaireData(
        "IV",
        "AN3",
        "In the past seven days, have you felt worried?",
      ),
      Level2AdultQuestionnaireData(
        "IV",
        "AN4",
        "In the past seven days, have you found it hard to focus on anything other than my anxiety?",
      ),
      Level2AdultQuestionnaireData(
        "IV",
        "AN5",
        "In the past seven days, have you felt nervous?",
      ),
      Level2AdultQuestionnaireData(
        "IV",
        "AN6",
        "In the past seven days, have you felt uneasy?",
      ),
      Level2AdultQuestionnaireData(
        "IV",
        "AN7",
        "In the past seven days, have you felt tense?",
      ),
    ],
    "Somatic Symptoms": [
      Level2AdultQuestionnaireData(
        "V",
        "S1",
        "During the past 7 days, how much have you been bothered by Stomach Pain?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S2",
        "During the past 7 days, how much have you been bothered by Back Pain?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S3",
        "During the past 7 days, how much have you been bothered by Pain in your arms,legs,or joints(knees,hips,etc.)?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S4",
        "During the past 7 days, how much have you been bothered by Menstrual cramps or other problems with your periods(WOMEN ONLY)?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S5",
        "During the past 7 days, how much have you been bothered by Headaches?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S6",
        " During the past 7 days, how much have you been bothered by Chest Pain?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S7",
        "During the past 7 days, how much have you been bothered by Dizziness?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S8",
        "During the past 7 days, how much have you been bothered by Fainting Spells?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S9",
        "During the past 7 days, how much have you been bothered by Feeling your heart pound or race?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S10",
        " During the past 7 days, how much have you been bothered by Shortness of breath?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S11",
        "During the past 7 days, how much have you been bothered by pain or problems during sexual intercourse?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S12",
        "During the past 7 days, how much have you been bothered by constipation,loose bowels or diarrhea?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S13",
        " During the past 7 days, how much have you been bothered by Nausea,gas or indigestion?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S14",
        "During the past 7 days, how much have you been bothered by feeling tired or having low energy?",
      ),
      Level2AdultQuestionnaireData(
        "V",
        "S15",
        "During the past 7 days, how much have you been bothered by trouble sleeping?",
      ),
    ],
    "Sleep Problems": [
      Level2AdultQuestionnaireData(
        "VIII",
        "SD1",
        "In the past seven days, was your sleep restless?",
      ),
      Level2AdultQuestionnaireData(
        "VIII",
        "SD2",
        "In the past seven days, were you satisfied with your sleep?",
      ),
      Level2AdultQuestionnaireData(
        "VIII",
        "SD3",
        "In the past seven days, was your sleep refreshing?",
      ),
      Level2AdultQuestionnaireData(
        "VIII",
        "SD4",
        "In the past seven days, have you had difficulty falling asleep?",
      ),
      Level2AdultQuestionnaireData(
        "VIII",
        "SD5",
        "In the past seven days, have you had trouble staying asleep?",
      ),
      Level2AdultQuestionnaireData(
        "VIII",
        "SD6",
        "In the past seven days, have you had trouble sleeping",
      ),
      Level2AdultQuestionnaireData(
        "VIII",
        "SD7",
        "In the past seven days, have you got enough sleep?",
      ),
      Level2AdultQuestionnaireData(
        "VIII",
        "SD8",
        " In the past seven days, how was your sleep quality?",
      ),
    ],
    "Repetitive Thoughts and Behaviors": [
      Level2AdultQuestionnaireData(
        "X",
        "R1",
        "On average, how much time is occupied by unwanted thoughts or behaviours each day?",
      ),
      Level2AdultQuestionnaireData(
        "X",
        "R2",
        " How much distress do these thoughts or behaviours cause you?",
      ),
      Level2AdultQuestionnaireData(
        "X",
        "R3",
        "How hard is it for you to control these thoughts or behaviours?",
      ),
      Level2AdultQuestionnaireData(
        "X",
        "R4",
        "How much do these thoughts or behaviours cause you to avoid doing anything , going any place, or being with anyone?",
      ),
      Level2AdultQuestionnaireData(
        "X",
        "R5",
        "How much do these thoughts or behaviours interfere with school,work,or your social or family life?",
      ),
    ],
    "Substance Use": [
      Level2AdultQuestionnaireData(
        "XIII",
        "SU1",
        "During the past TWO WEEKS, about how often did you use Painkillers(like Vicodin) ON YOUR OWN, that is, without a doctor’s prescription, in greater amounts or longer than prescribed?",
      ),
      Level2AdultQuestionnaireData(
        "XIII",
        "SU2",
        "During the past TWO WEEKS, about how often did you use Stimulants(like Ritalin,Adderall) ON YOUR OWN, that is, without a doctor’s prescription, in greater amounts or longer than prescribed?",
      ),
      Level2AdultQuestionnaireData(
        "XIII",
        "SU3",
        "During the past TWO WEEKS, about how often did you use Sedatives or tranquilizers (like sleeping pills or Valium) ON YOUR OWN, that is, without a doctor’s prescription, in greater amounts or longer than prescribed?",
      ),
      Level2AdultQuestionnaireData(
        "XIII",
        "SU4",
        "During the past TWO WEEKS, about how often did you use Marijuana?",
      ),
      Level2AdultQuestionnaireData(
        "XIII",
        "SU5",
        "During the past TWO WEEKS, about how often did you use Cocaine or crack?",
      ),
      Level2AdultQuestionnaireData(
        "XIII",
        "SU6",
        "During the past TWO WEEKS, about how often did you use Club drugs (like ecstasy)?",
      ),
      Level2AdultQuestionnaireData(
        "XIII",
        "SU7",
        "During the past TWO WEEKS, about how often did you use Hallucinogens (like LSD)?",
      ),
      Level2AdultQuestionnaireData(
        "XIII",
        "SU8",
        "During the past TWO WEEKS, about how often did you use Heroin?",
      ),
      Level2AdultQuestionnaireData(
        "XIII",
        "SU9",
        "During the past TWO WEEKS, about how often did you use Inhalants or solvents (like glue)?",
      ),
      Level2AdultQuestionnaireData(
        "XIII",
        "SU10",
        "During the past TWO WEEKS, about how often did you use Methamphetamine (like speed)",
      ),
    ],
  };

  static final Map<String, List<Level2AdolescentQuestionnaireData>>
  _level2AdolescentQuestions = {
    "Somatic Symptoms": [
      Level2AdolescentQuestionnaireData(
        "1",
        "S1",
        "During the past 7 days, how much have you been bothered by Stomach pain?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S2",
        "During the past 7 days, how much have you been bothered by Back pain?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S3",
        "During the past 7 days, how much have you been bothered by Pain in your arms, legs, or joints (knees, hips, etc.)?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S4",
        "During the past 7 days, how much have you been bothered by Headaches?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S5",
        "During the past 7 days, how much have you been bothered by Chest pain?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S6",
        "During the past 7 days, how much have you been bothered by Dizziness?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S7",
        "During the past 7 days, how much have you been bothered by Fainting spells?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S8",
        "During the past 7 days, how much have you been bothered by Feeling your heart pound or race?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S9",
        "During the past 7 days, how much have you been bothered by Shortness of breath?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S10",
        "During the past 7 days, how much have you been bothered by Constipation, loose bowels, or diarrhea?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S11",
        "During the past 7 days, how much have you been bothered by Nausea, gas, or indigestion?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S12",
        "During the past 7 days, how much have you been bothered by Feeling tired or having low energy?",
      ),
      Level2AdolescentQuestionnaireData(
        "1",
        "S13",
        "During the past 7 days, how much have you been bothered by Trouble sleeping?",
      ),
    ],
    "Sleep Problems": [
      Level2AdolescentQuestionnaireData(
        "2",
        "SD1",
        "In the past SEVEN (7) DAYS, my sleep was restless.",
      ),
      Level2AdolescentQuestionnaireData(
        "2",
        "SD2",
        "In the past SEVEN (7) DAYS, I was satisfied with my sleep.",
      ),
      Level2AdolescentQuestionnaireData(
        "2",
        "SD3",
        "In the past SEVEN (7) DAYS, my sleep was refreshing.",
      ),
      Level2AdolescentQuestionnaireData(
        "2",
        "SD4",
        "In the past SEVEN (7) DAYS, I had difficulty falling asleep.",
      ),
      Level2AdolescentQuestionnaireData(
        "2",
        "SD5",
        "In the past SEVEN (7) DAYS, I had trouble staying asleep.",
      ),
      Level2AdolescentQuestionnaireData(
        "2",
        "SD6",
        "In the past SEVEN (7) DAYS, I had trouble sleeping.",
      ),
      Level2AdolescentQuestionnaireData(
        "2",
        "SD7",
        "In the past SEVEN (7) DAYS, I got enough sleep.",
      ),
      Level2AdolescentQuestionnaireData(
        "2",
        "SD8",
        "In the past SEVEN (7) DAYS, my sleep quality was...",
      ),
    ],
    "Depression": [
      Level2AdolescentQuestionnaireData(
        "3",
        "D1",
        "In the past SEVEN (7) DAYS, I could not stop feeling sad.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D2",
        "In the past SEVEN (7) DAYS, I felt alone.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D3",
        "In the past SEVEN (7) DAYS, I felt everything in my life went wrong.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D4",
        "In the past SEVEN (7) DAYS, I felt like I couldn't do anything right.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D5",
        "In the past SEVEN (7) DAYS, I felt lonely.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D6",
        "In the past SEVEN (7) DAYS, I felt sad.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D7",
        "In the past SEVEN (7) DAYS, I felt unhappy.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D8",
        "In the past SEVEN (7) DAYS, I thought that my life was bad.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D9",
        "In the past SEVEN (7) DAYS, being sad made it hard for me to do things with my friends.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D10",
        "In the past SEVEN (7) DAYS, I didn't care about anything.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D11",
        "In the past SEVEN (7) DAYS, I felt stressed.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D12",
        "In the past SEVEN (7) DAYS, I felt too sad to eat.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D13",
        "In the past SEVEN (7) DAYS, I wanted to be by myself.",
      ),
      Level2AdolescentQuestionnaireData(
        "3",
        "D14",
        "In the past SEVEN (7) DAYS, it was hard for me to have fun.",
      ),
    ],
    "Anger": [
      Level2AdolescentQuestionnaireData(
        "4",
        "A1",
        "In the past SEVEN (7) DAYS, I felt mad.",
      ),
      Level2AdolescentQuestionnaireData(
        "4",
        "A2",
        "In the past SEVEN (7) DAYS, I was so angry I felt like throwing something.",
      ),
      Level2AdolescentQuestionnaireData(
        "4",
        "A3",
        "In the past SEVEN (7) DAYS, I was so angry I felt like yelling at somebody.",
      ),
      Level2AdolescentQuestionnaireData(
        "4",
        "A4",
        "In the past SEVEN (7) DAYS, when I got mad, I stayed mad.",
      ),
      Level2AdolescentQuestionnaireData(
        "4",
        "A5",
        "In the past SEVEN (7) DAYS, I felt fed up.",
      ),
      Level2AdolescentQuestionnaireData(
        "4",
        "A6",
        "In the past SEVEN (7) DAYS, I felt upset.",
      ),
    ],
    "Irritability": [
      Level2AdolescentQuestionnaireData(
        "5",
        "I1",
        "In the last SEVEN (7) DAYS, am easily annoyed by others.",
      ),
      Level2AdolescentQuestionnaireData(
        "5",
        "I2",
        "In the last SEVEN (7) DAYS, often lose my temper.",
      ),
      Level2AdolescentQuestionnaireData(
        "5",
        "I3",
        "In the last SEVEN (7) DAYS, stay angry for a long time.",
      ),
      Level2AdolescentQuestionnaireData(
        "5",
        "I4",
        "In the last SEVEN (7) DAYS, am angry most of the time.",
      ),
      Level2AdolescentQuestionnaireData(
        "5",
        "I5",
        "In the last SEVEN (7) DAYS, get angry frequently.",
      ),
      Level2AdolescentQuestionnaireData(
        "5",
        "I6",
        "In the last SEVEN (7) DAYS, lose temper easily.",
      ),
      Level2AdolescentQuestionnaireData(
        "5",
        "I7",
        "In the last SEVEN (7) DAYS, overall irritability causes me problems.",
      ),
    ],
    "Mania": [
      Level2AdolescentQuestionnaireData(
        "6",
        "M1",
        "Do you feel happier or more cheerful than usual?",
      ),
      Level2AdolescentQuestionnaireData(
        "6",
        "M2",
        "Do you feel more self-confident than usual?",
      ),
      Level2AdolescentQuestionnaireData(
        "6",
        "M3",
        "Do you need less sleep than usual?",
      ),
      Level2AdolescentQuestionnaireData(
        "6",
        "M4",
        "Do you talk more than usual?",
      ),
      Level2AdolescentQuestionnaireData(
        "6",
        "M5",
        "Have you been more active than usual?",
      ),
    ],
    "Anxiety": [
      Level2AdolescentQuestionnaireData(
        "7",
        "AN1",
        "In the past SEVEN (7) DAYS, I felt like something awful might happen.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN2",
        "In the past SEVEN (7) DAYS, I felt nervous.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN3",
        "In the past SEVEN (7) DAYS, I felt scared.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN4",
        "In the past SEVEN (7) DAYS, I felt worried.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN5",
        "In the past SEVEN (7) DAYS, I worried about what could happen to me.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN6",
        "In the past SEVEN (7) DAYS, I worried when I went to bed at night.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN7",
        "In the past SEVEN (7) DAYS, I got scared really easy.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN8",
        "In the past SEVEN (7) DAYS, I was afraid of going to school.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN9",
        "In the past SEVEN (7) DAYS, I was worried I might die.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN10",
        "In the past SEVEN (7) DAYS, I woke up at night scared.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN11",
        "In the past SEVEN (7) DAYS, I worried when I was at home.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN12",
        "In the past SEVEN (7) DAYS, I worried when I was away from home.",
      ),
      Level2AdolescentQuestionnaireData(
        "7",
        "AN13",
        "In the past SEVEN (7) DAYS, it was hard for me to relax.",
      ),
    ],
    "Repetitive Thoughts and Behaviors": [
      Level2AdolescentQuestionnaireData(
        "8",
        "R1",
        "During the past SEVEN (7) DAYS, on average, how much time is occupied by these thoughts or behaviors each day?",
      ),
      Level2AdolescentQuestionnaireData(
        "8",
        "R2",
        "During the past SEVEN (7) DAYS, how much do they bother you?",
      ),
      Level2AdolescentQuestionnaireData(
        "8",
        "R3",
        "During the past SEVEN (7) DAYS, how hard is it for you to control them?",
      ),
      Level2AdolescentQuestionnaireData(
        "8",
        "R4",
        "During the past SEVEN (7) DAYS, how much do they cause you to avoid doing things, going places or being with people?",
      ),
      Level2AdolescentQuestionnaireData(
        "8",
        "R5",
        "During the past SEVEN (7) DAYS, how much do they interfere with school, your social or family life, or your job?",
      ),
    ],
    "Substance Use": [
      Level2AdolescentQuestionnaireData(
        "9",
        "SU1",
        "During the past TWO (2) weeks, about how often did you have an alcoholic beverage (beer, wine, liquor, etc.)?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU2",
        "During the past TWO (2) weeks, about how often did you have 4 or more drinks in a single day?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU3",
        "During the past TWO (2) weeks, about how often did you smoke a cigarette, a cigar, or pipe or use snuff or chewing tobacco?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU4",
        "During the past TWO (2) weeks, about how often did you use Painkillers (like Vicodin) ON YOUR OWN?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU5",
        "During the past TWO (2) weeks, about how often did you use Stimulants (like Ritalin, Adderall) ON YOUR OWN?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU6",
        "During the past TWO (2) weeks, about how often did you use Sedatives or tranquilizers (like sleeping pills or Valium) ON YOUR OWN?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU7",
        "During the past TWO (2) weeks, about how often did you use Steroids?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU8",
        "During the past TWO (2) weeks, about how often did you use Marijuana?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU9",
        "During the past TWO (2) weeks, about how often did you use Cocaine or crack?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU10",
        "During the past TWO (2) weeks, about how often did you use Club drugs (like ecstasy)?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU11",
        "During the past TWO (2) weeks, about how often did you use Hallucinogens (like LSD)?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU12",
        "During the past TWO (2) weeks, about how often did you use Heroin?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU13",
        "During the past TWO (2) weeks, about how often did you use Inhalants or solvents (like glue)?",
      ),
      Level2AdolescentQuestionnaireData(
        "9",
        "SU14",
        "During the past TWO (2) weeks, about how often did you use Methamphetamine (like speed)?",
      ),
    ],
  };

  static List<Level2AdultQuestionnaireData> getAdultLevel2Questions(
    String domainName,
  ) {
    return _level2AdultQuestions[domainName] ?? [];
  }

  static List<Level2AdolescentQuestionnaireData> getAdolescentLevel2Questions(
    String domainName,
  ) {
    return _level2AdolescentQuestions[domainName] ?? [];
  }
}

Future<String?> getMLDiagnosis(
  String domainName,
  List<int> scores,
  int userAge,
) async {
  String baseUrl = 'https://mindgaugebackend.onrender.com/predict';
  final url = Uri.parse(baseUrl);
  List<int> slicedScores;

  // Standardize the key to match Python name_map exactly
  String domainKey = domainName.toLowerCase().trim();

  try {
    switch (domainKey) {
      case 'level1':
        slicedScores = scores;
        domainKey = 'level1';
        break;
      case 'depression':
        slicedScores = scores.sublist(0, 2);
        domainKey = 'depression';
        break;
      case 'anger':
        slicedScores = scores.sublist(2, 3);
        domainKey = 'anger';
        break;
      case 'mania':
        slicedScores = scores.sublist(3, 5);
        domainKey = 'mania';
        break;
      case 'anxiety':
        slicedScores = scores.sublist(5, 8);
        domainKey = 'anxiety';
        break;
      case 'somatic symptoms':
        slicedScores = scores.sublist(8, 10);
        domainKey = 'somatic';
        break;
      case 'sleep problems':
        slicedScores = scores.sublist(13, 14);
        domainKey = 'sleep';
        break;
      case 'repetitive thoughts and behaviors':
        slicedScores = scores.sublist(15, 17);
        domainKey = 'repetitive_thoughts';
        break;
      case 'substance use':
        slicedScores = scores.sublist(20, 23);
        domainKey = 'substance_use';
        break;
      default:
        slicedScores = scores.take(2).toList();
    }
  } catch (e) {
    slicedScores = scores.take(2).toList();
  }

  try {
    final body = jsonEncode({
      "group": userAge >= 18 ? "adult" : "children",
      "domain": domainKey,
      "responses": slicedScores,
    });

    final response = await http
        .post(url, headers: {"Content-Type": "application/json"}, body: body)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return result['prediction'];
    } else {
      print("ML Server Error ${response.statusCode}: ${response.body}");
      return null;
    }
  } catch (e) {
    print("Connection failed: $e");
    return null;
  }
}

Future<String?> getLevel2MLDiagnosis(
  String domainName,
  List<int> scores,
  int userAge,
) async {
  String baseUrl = 'https://mindgaugebackend.onrender.com/predict';
  final url = Uri.parse(baseUrl);

  String domainKey = domainName.toLowerCase().trim();

  try {
    String apiDomain = domainKey;
    if (domainKey == 'somatic symptoms') apiDomain = 'somatic';
    if (domainKey == 'sleep problems') apiDomain = 'sleep';
    if (domainKey == 'repetitive thoughts and behaviors') {
      apiDomain = 'repetitive_thoughts';
    }
    if (domainKey == 'substance use') apiDomain = 'substance_use';

    final body = jsonEncode({
      "group": userAge >= 18 ? "adult" : "children",
      "domain": apiDomain,
      "responses": scores,
      "level": 2,
    });

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "x-api-key": "mindgauge-secure-api-key-2024"
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return result['prediction'];
    } else {
      print("ML Server Error ${response.statusCode}: ${response.body}");
      return null;
    }
  } catch (e) {
    print("Connection failed: $e");
    return null;
  }
}

Future<SentimentResult?> analyzeSentiment(String text) async {
  String baseUrl = 'https://mindgaugebackend.onrender.com/analyze_sentiment';
  final url = Uri.parse(baseUrl);

  try {
    final body = jsonEncode({"text": text});

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "x-api-key": "mindgauge-secure-api-key-2024"
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return SentimentResult(
        result['emoji'],
        (result['score'] as num).toDouble(),
        result['description'],
      );
    } else {
      print("Sentiment Server Error ${response.statusCode}: ${response.body}");
      return null;
    }
  } catch (e) {
    print("Sentiment Connection failed: $e");
    return null;
  }
}

class MockSentimentService {
  final FirestoreJournalService _journalService = FirestoreJournalService();
  final SentimentResult _empty = const SentimentResult("⚪", 0.0, "No entry");

  SentimentResult analyze(String text) {
    if (text.isEmpty) return _empty;

    final lower = text.toLowerCase();

    if (lower.contains('excited') || lower.contains('thrilled') || lower.contains('overjoyed') || lower.contains('ecstatic')) {
      return const SentimentResult("🤩", 0.9, "Excited");
    }
    if (lower.contains('grateful') || lower.contains('thankful') || lower.contains('blessed')) {
      return const SentimentResult("🙏", 0.8, "Grateful");
    }
    if (lower.contains('angry') || lower.contains('mad') || lower.contains('frustrated') || lower.contains('furious') || lower.contains('annoyed')) {
      return const SentimentResult("😠", -0.6, "Angry");
    }
    if (lower.contains('anxious') || lower.contains('nervous') || lower.contains('worried') || lower.contains('scared') || lower.contains('fear')) {
      return const SentimentResult("😰", -0.5, "Anxious");
    }
    if (lower.contains('stressed') || lower.contains('overwhelmed') || lower.contains('pressured')) {
      return const SentimentResult("😫", -0.6, "Stressed");
    }
    if (lower.contains('tired') || lower.contains('exhausted') || lower.contains('sleepy') || lower.contains('fatigued')) {
      return const SentimentResult("😴", 0.0, "Tired");
    }
    if (lower.contains('confused') || lower.contains('unsure') || lower.contains('puzzled')) {
      return const SentimentResult("😕", 0.0, "Confused");
    }
    if (lower.contains('bored') || lower.contains('uninspired') || lower.contains('dull')) {
      return const SentimentResult("🥱", 0.0, "Bored");
    }
    if (lower.contains('proud') || lower.contains('confident') || lower.contains('accomplished')) {
      return const SentimentResult("😌", 0.7, "Proud");
    }
    if (lower.contains('down') || lower.contains('sad') || lower.contains('bad') || lower.contains('terrible') || lower.contains('horrible') || lower.contains('worst') || lower.contains('hate') || lower.contains('awful')) {
      return const SentimentResult("😞", -0.7, "Feeling low");
    }
    if (lower.contains('happy') || lower.contains('great') || lower.contains('wonderful') || lower.contains('amazing') || lower.contains('love') || lower.contains('best') || lower.contains('fantastic') || lower.contains('good')) {
      return const SentimentResult("😊", 0.8, "Positive mood");
    }

    return const SentimentResult("😐", 0.0, "Neutral");
  }

  Future<void> saveEntry(String uid, JournalEntry entry) async {
    await _journalService.saveEntry(uid, entry);
  }

  Future<List<JournalEntry>> getAllEntries(String uid) async {
    return _journalService.getAllEntries(uid);
  }

  Future<JournalEntry?> getEntry(String uid, DateTime date) async {
    return _journalService.getEntry(uid, date);
  }
}

extension DateOnlyCompare on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}