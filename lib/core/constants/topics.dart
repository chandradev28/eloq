import 'package:flutter/material.dart';

import '../../features/topics/models/topic.dart';

class Topics {
  const Topics._();

  static const all = [
    Topic(
      id: 'restaurant',
      name: 'Restaurant',
      icon: Icons.restaurant_rounded,
      description: 'Ordering food and talking to a waiter.',
      prompt: 'You are a waiter at a restaurant. Greet the customer and take their order.',
      difficulty: 'Beginner',
    ),
    Topic(
      id: 'job_interview',
      name: 'Job Interview',
      icon: Icons.work_rounded,
      description: 'Answer interview questions with confidence.',
      prompt: 'You are a hiring manager interviewing the student for a junior position. Ask common interview questions.',
      difficulty: 'Intermediate',
    ),
    Topic(
      id: 'travel',
      name: 'Airport & Travel',
      icon: Icons.flight_takeoff_rounded,
      description: 'Check-in, customs, directions, and travel issues.',
      prompt: 'You are an airport staff member helping a traveler check in for their flight.',
      difficulty: 'Beginner',
    ),
    Topic(
      id: 'doctor',
      name: 'Doctor Visit',
      icon: Icons.local_hospital_rounded,
      description: 'Describe symptoms and understand advice.',
      prompt: 'You are a doctor. The patient has come in with a complaint. Ask about their symptoms.',
      difficulty: 'Intermediate',
    ),
    Topic(
      id: 'shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      description: 'Ask prices, sizes, returns, and preferences.',
      prompt: 'You are a shop assistant in a clothing store. Help the customer find what they need.',
      difficulty: 'Beginner',
    ),
    Topic(
      id: 'casual',
      name: 'Casual Chat',
      icon: Icons.chat_bubble_rounded,
      description: 'Everyday conversation about life and interests.',
      prompt: 'Have a casual, friendly conversation about daily life, hobbies, and interests.',
      difficulty: 'Beginner',
    ),
    Topic(
      id: 'hotel',
      name: 'Hotel Check-in',
      icon: Icons.hotel_rounded,
      description: 'Booking, check-in, and room issues.',
      prompt: 'You are a hotel receptionist. Help the guest check in.',
      difficulty: 'Beginner',
    ),
    Topic(
      id: 'phone',
      name: 'Phone Call',
      icon: Icons.call_rounded,
      description: 'Make appointments and handle service calls.',
      prompt: 'You are a receptionist at a dental clinic. The student is calling to book an appointment.',
      difficulty: 'Intermediate',
    ),
    Topic(
      id: 'directions',
      name: 'Giving Directions',
      icon: Icons.map_rounded,
      description: 'Ask for and give clear directions.',
      prompt: 'A tourist asks you for directions to the nearest train station. Help them.',
      difficulty: 'Beginner',
    ),
    Topic(
      id: 'small_talk',
      name: 'Small Talk',
      icon: Icons.coffee_rounded,
      description: 'Weather, weekends, compliments, and quick chats.',
      prompt: 'You meet the student at a coffee shop. Make small talk.',
      difficulty: 'Beginner',
    ),
    Topic(
      id: 'storytelling',
      name: 'Storytelling',
      icon: Icons.menu_book_rounded,
      description: 'Practice past tense and narrative flow.',
      prompt: 'Ask the student to tell you about their last vacation or a memorable experience.',
      difficulty: 'Intermediate',
    ),
    Topic(
      id: 'debate',
      name: 'Debate & Opinions',
      icon: Icons.track_changes_rounded,
      description: 'Express views and defend opinions.',
      prompt: 'Discuss whether social media is good or bad for society. Present your view and ask for theirs.',
      difficulty: 'Advanced',
    ),
    Topic(
      id: 'emergency',
      name: 'Emergency',
      icon: Icons.emergency_rounded,
      description: 'Call for help and report incidents clearly.',
      prompt: 'You are a 911 operator. The student needs to report an emergency.',
      difficulty: 'Intermediate',
    ),
    Topic(
      id: 'meeting_people',
      name: 'Meeting People',
      icon: Icons.handshake_rounded,
      description: 'Introductions and getting to know someone.',
      prompt: 'You just met the student at a party. Introduce yourself and get to know them.',
      difficulty: 'Beginner',
    ),
    Topic(
      id: 'free_talk',
      name: 'Free Talk',
      icon: Icons.mic_rounded,
      description: 'Open conversation about anything.',
      prompt: 'Have an open conversation about anything the student wants to talk about. Be a good listener.',
      difficulty: 'Beginner',
    ),
  ];

  static Topic byId(String id) => all.firstWhere(
        (topic) => topic.id == id,
        orElse: () => all.first,
      );
}
