import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/contacts_provider.dart';
import '../models/contact.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';

/// Widget para mostrar lista de contactos/favoritos
class ContactsList extends ConsumerWidget {
  final Function(Contact)? onContactTap;
  final bool showFavoritesOnly;

  const ContactsList({
    Key? key,
    this.onContactTap,
    this.showFavoritesOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsState = ref.watch(contactsProvider);
    final appTheme = ref.watch(themeProvider);

    List<Contact> contacts = showFavoritesOnly
        ? contactsState.contacts.where((c) => c.isFavorite).toList()
        : contactsState.contacts;

    if (contactsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (contacts.isEmpty) {
      return Center(
        child: Text(
          showFavoritesOnly ? 'No hay favoritos' : 'No hay contactos',
          style: TextStyle(color: appTheme.textSecondary),
        ),
      );
    }

    // Agrupar por grupo si hay grupos
    final groupedContacts = <String, List<Contact>>{};
    final ungroupedContacts = <Contact>[];

    for (final contact in contacts) {
      if (contact.group != null && contact.group!.isNotEmpty) {
        if (!groupedContacts.containsKey(contact.group)) {
          groupedContacts[contact.group!] = [];
        }
        groupedContacts[contact.group!]!.add(contact);
      } else {
        ungroupedContacts.add(contact);
      }
    }

    return ListView.builder(
      itemCount: groupedContacts.length + ungroupedContacts.length + (ungroupedContacts.isNotEmpty && groupedContacts.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        int currentIndex = 0;

        // Mostrar grupos primero
        for (final entry in groupedContacts.entries) {
          if (index == currentIndex) {
            // Header del grupo
            return _buildGroupHeader(context, appTheme, entry.key);
          }
          currentIndex++;

          for (final contact in entry.value) {
            if (index == currentIndex) {
              return _buildContactTile(context, ref, appTheme, contact);
            }
            currentIndex++;
          }
        }

        // Separador si hay grupos y contactos sin grupo
        if (ungroupedContacts.isNotEmpty && groupedContacts.isNotEmpty) {
          if (index == currentIndex) {
            return Divider(color: appTheme.textSecondary.withOpacity(0.2));
          }
          currentIndex++;
        }

        // Contactos sin grupo
        final ungroupedIndex = index - currentIndex;
        if (ungroupedIndex < ungroupedContacts.length) {
          return _buildContactTile(context, ref, appTheme, ungroupedContacts[ungroupedIndex]);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildGroupHeader(BuildContext context, AppTheme theme, String groupName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.surface,
      child: Text(
        groupName,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.primary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context,
    WidgetRef ref,
    AppTheme theme,
    Contact contact,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.primary,
        child: Text(
          contact.nick[0].toUpperCase(),
          style: TextStyle(color: theme.textPrimary),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              contact.nick,
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: contact.isFavorite ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (contact.isFavorite)
            Icon(Icons.star, color: Colors.amber, size: 16),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contact.realName != null)
            Text(
              contact.realName!,
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          if (contact.tags.isNotEmpty)
            Wrap(
              spacing: 4,
              children: contact.tags.take(3).map((tag) {
                return Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 10)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
        ],
      ),
      trailing: contact.isBlocked
          ? Icon(Icons.block, color: Colors.red, size: 20)
          : null,
      onTap: () => onContactTap?.call(contact),
    );
  }
}

