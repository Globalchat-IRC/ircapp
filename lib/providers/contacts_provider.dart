import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/contact.dart';

class ContactsState {
  final List<Contact> contacts;
  final List<String> groups;
  final bool isLoading;

  const ContactsState({
    this.contacts = const [],
    this.groups = const [],
    this.isLoading = false,
  });

  ContactsState copyWith({
    List<Contact>? contacts,
    List<String>? groups,
    bool? isLoading,
  }) {
    return ContactsState(
      contacts: contacts ?? this.contacts,
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ContactsNotifier extends StateNotifier<ContactsState> {
  ContactsNotifier() : super(const ContactsState()) {
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getString('contacts_list');
      final groupsJson = prefs.getString('contact_groups');

      List<Contact> contacts = [];
      if (contactsJson != null) {
        final List<dynamic> decoded = jsonDecode(contactsJson);
        contacts = decoded.map((json) => Contact.fromJson(json as Map<String, dynamic>)).toList();
      }

      List<String> groups = [];
      if (groupsJson != null) {
        groups = List<String>.from(jsonDecode(groupsJson));
      }

      state = state.copyWith(
        contacts: contacts,
        groups: groups,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = jsonEncode(state.contacts.map((c) => c.toJson()).toList());
    await prefs.setString('contacts_list', contactsJson);
  }

  Future<void> addContact(Contact contact) async {
    final contacts = List<Contact>.from(state.contacts);
    if (!contacts.any((c) => c.nick.toLowerCase() == contact.nick.toLowerCase())) {
      contacts.add(contact);
      state = state.copyWith(contacts: contacts);
      await _saveContacts();
    }
  }

  Future<void> updateContact(Contact contact) async {
    final contacts = List<Contact>.from(state.contacts);
    final index = contacts.indexWhere((c) => c.nick.toLowerCase() == contact.nick.toLowerCase());
    if (index != -1) {
      contacts[index] = contact;
      state = state.copyWith(contacts: contacts);
      await _saveContacts();
    }
  }

  Future<void> removeContact(String nick) async {
    final contacts = List<Contact>.from(state.contacts);
    contacts.removeWhere((c) => c.nick.toLowerCase() == nick.toLowerCase());
    state = state.copyWith(contacts: contacts);
    await _saveContacts();
  }

  Future<void> toggleFavorite(String nick) async {
    final contacts = List<Contact>.from(state.contacts);
    final index = contacts.indexWhere((c) => c.nick.toLowerCase() == nick.toLowerCase());
    if (index != -1) {
      contacts[index] = contacts[index].copyWith(isFavorite: !contacts[index].isFavorite);
      state = state.copyWith(contacts: contacts);
      await _saveContacts();
    }
  }

  Future<void> addTag(String nick, String tag) async {
    final contacts = List<Contact>.from(state.contacts);
    final index = contacts.indexWhere((c) => c.nick.toLowerCase() == nick.toLowerCase());
    if (index != -1) {
      final currentTags = List<String>.from(contacts[index].tags);
      if (!currentTags.contains(tag)) {
        currentTags.add(tag);
        contacts[index] = contacts[index].copyWith(tags: currentTags);
        state = state.copyWith(contacts: contacts);
        await _saveContacts();
      }
    }
  }

  Future<void> removeTag(String nick, String tag) async {
    final contacts = List<Contact>.from(state.contacts);
    final index = contacts.indexWhere((c) => c.nick.toLowerCase() == nick.toLowerCase());
    if (index != -1) {
      final currentTags = List<String>.from(contacts[index].tags);
      currentTags.remove(tag);
      contacts[index] = contacts[index].copyWith(tags: currentTags);
      state = state.copyWith(contacts: contacts);
      await _saveContacts();
    }
  }

  Future<void> addGroup(String groupName) async {
    final groups = List<String>.from(state.groups);
    if (!groups.contains(groupName)) {
      groups.add(groupName);
      state = state.copyWith(groups: groups);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('contact_groups', jsonEncode(groups));
    }
  }

  Future<void> setContactGroup(String nick, String? group) async {
    final contacts = List<Contact>.from(state.contacts);
    final index = contacts.indexWhere((c) => c.nick.toLowerCase() == nick.toLowerCase());
    if (index != -1) {
      contacts[index] = contacts[index].copyWith(group: group);
      state = state.copyWith(contacts: contacts);
      await _saveContacts();
    }
  }

  List<Contact> getFavoriteContacts() {
    return state.contacts.where((c) => c.isFavorite).toList();
  }

  List<Contact> getContactsByGroup(String group) {
    return state.contacts.where((c) => c.group == group).toList();
  }
}

final contactsProvider = StateNotifierProvider<ContactsNotifier, ContactsState>((ref) {
  return ContactsNotifier();
});




