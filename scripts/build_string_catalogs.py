#!/usr/bin/env python3
"""Generate the app's String Catalogs from a single translation table.

Run this instead of hand-editing the .xcstrings JSON, then let Xcode take over:
once the catalogs exist, Xcode merges newly extracted keys on every build.
"""

import json
import os

LANGS = ["de", "es", "fr", "it", "ja", "pt-BR"]

# key -> {lang: translation}. The key is the English source string, which is what
# SwiftUI's Text("...") / String(localized:) look up.
T = {}


def add(key, de, es, fr, it, ja, pt):
    T[key] = {"de": de, "es": es, "fr": fr, "it": it, "ja": ja, "pt-BR": pt}


# --- Tabs -------------------------------------------------------------------
add("My Wishlist", "Meine Liste", "Mi lista", "Ma liste", "La mia lista", "マイリスト", "Minha lista")
add("Our Wishlists", "Unsere Listen", "Nuestras listas", "Nos listes", "Le nostre liste", "みんなのリスト", "Nossas listas")
add("Our Wishlist", "Unsere Liste", "Nuestra lista", "Notre liste", "La nostra lista", "みんなのリスト", "Nossa lista")
add("%@'s Wishlist", "Wunschliste von %@", "Lista de %@", "Liste de %@", "Lista di %@", "%@のリスト", "Lista de %@")
add("Friends", "Freunde", "Amigos", "Amis", "Amici", "友だち", "Amigos")
add("Ask Santa", "Weihnachtsmann", "Papá Noel", "Père Noël", "Babbo Natale", "サンタに聞く", "Papai Noel")
add("Settings", "Einstellungen", "Ajustes", "Réglages", "Impostazioni", "設定", "Ajustes")

# --- Common -----------------------------------------------------------------
add("Cancel", "Abbrechen", "Cancelar", "Annuler", "Annulla", "キャンセル", "Cancelar")
add("OK", "OK", "OK", "OK", "OK", "OK", "OK")
add("Error", "Fehler", "Error", "Erreur", "Errore", "エラー", "Erro")
add("Success", "Fertig", "Listo", "Terminé", "Fatto", "完了", "Pronto")
add("Continue", "Fortfahren", "Continuar", "Continuer", "Continua", "続ける", "Continuar")
add("Delete", "Löschen", "Eliminar", "Supprimer", "Elimina", "削除", "Excluir")
add("Edit", "Bearbeiten", "Editar", "Modifier", "Modifica", "編集", "Editar")
add("Save", "Sichern", "Guardar", "Enregistrer", "Salva", "保存", "Salvar")
add("Add", "Hinzufügen", "Añadir", "Ajouter", "Aggiungi", "追加", "Adicionar")
add("Done", "Fertig", "OK", "OK", "Fine", "完了", "OK")
add("Back", "Zurück", "Atrás", "Retour", "Indietro", "戻る", "Voltar")
add("Loading...", "Wird geladen …", "Cargando…", "Chargement…", "Caricamento…", "読み込み中…", "Carregando…")
add("Invite", "Einladen", "Invitar", "Inviter", "Invita", "招待", "Convidar")
add("No items yet", "Noch keine Wünsche", "Aún no hay artículos", "Aucun article pour l’instant", "Ancora nessun articolo", "アイテムはまだありません", "Nenhum item ainda")

# --- Emoji-only labels (identical everywhere, kept so the catalog stays clean)
for emoji in ["🎁", "❄️", "✨", "🎮", "📚"]:
    add(emoji, emoji, emoji, emoji, emoji, emoji, emoji)
# --- Settings ---------------------------------------------------------------
add("Profile", "Profil", "Perfil", "Profil", "Profilo", "プロフィール", "Perfil")
add("Manage Children", "Kinder verwalten", "Gestionar niños", "Gérer les enfants", "Gestisci i bambini", "子どもを管理", "Gerenciar crianças")
add("Kids without a phone", "Kinder ohne eigenes Handy", "Niños sin teléfono", "Enfants sans téléphone", "Bambini senza telefono", "スマホを持たない子ども", "Crianças sem celular")
add(
    "Add kids who don't have their own phone. Their wish lists will be available when friends connect to you.",
    "Füge Kinder hinzu, die noch kein eigenes Handy haben. Ihre Wunschlisten sind sichtbar, sobald Freunde sich mit dir verbinden.",
    "Añade niños que aún no tienen teléfono propio. Sus listas estarán disponibles cuando tus amigos se conecten contigo.",
    "Ajoutez les enfants qui n’ont pas encore de téléphone. Leurs listes seront visibles dès que vos amis se connecteront à vous.",
    "Aggiungi i bambini che non hanno ancora un telefono. Le loro liste saranno visibili quando gli amici si collegheranno a te.",
    "自分のスマホを持っていない子どもを追加できます。友だちがあなたとつながると、その子のリストも表示されます。",
    "Adicione crianças que ainda não têm celular. As listas delas ficarão disponíveis quando seus amigos se conectarem a você.",
)
add("Secrecy", "Überraschungen", "Sorpresas", "Surprises", "Sorprese", "サプライズ", "Surpresas")
add("Show purchased status", "Gekaufte Wünsche anzeigen", "Mostrar lo ya comprado", "Afficher les articles achetés", "Mostra gli articoli acquistati", "購入済みを表示", "Mostrar itens comprados")
add(
    "If on, you'll see when your wishlist items have been purchased.",
    "Wenn aktiviert, siehst du, wenn Wünsche von deiner Liste gekauft wurden.",
    "Si está activado, verás cuando alguien haya comprado artículos de tu lista.",
    "Si l’option est activée, vous verrez quand des articles de votre liste ont été achetés.",
    "Se attivo, vedrai quando gli articoli della tua lista sono stati acquistati.",
    "オンにすると、リストのアイテムが購入されたときに分かります。",
    "Se ativado, você verá quando os itens da sua lista tiverem sido comprados.",
)
add("Notifications", "Mitteilungen", "Notificaciones", "Notifications", "Notifiche", "通知", "Notificações")
add("Purchase notifications", "Mitteilungen zu Käufen", "Notificaciones de compra", "Notifications d’achat", "Notifiche di acquisto", "購入の通知", "Notificações de compra")
add(
    "Get notified when someone purchases from your wishlist.",
    "Erhalte eine Mitteilung, wenn jemand etwas von deiner Wunschliste kauft.",
    "Recibe un aviso cuando alguien compre algo de tu lista.",
    "Soyez averti lorsque quelqu’un achète un article de votre liste.",
    "Ricevi una notifica quando qualcuno acquista dalla tua lista.",
    "誰かがあなたのリストから購入したときに通知を受け取ります。",
    "Receba um aviso quando alguém comprar algo da sua lista.",
)
add("Support", "Support", "Soporte", "Assistance", "Assistenza", "サポート", "Suporte")
add("Rate App", "App bewerten", "Valorar la app", "Noter l’app", "Valuta l’app", "アプリを評価", "Avaliar o app")
add("Report a Bug", "Fehler melden", "Informar de un error", "Signaler un bug", "Segnala un problema", "不具合を報告", "Relatar um erro")
add("Wish for new app feature", "Neue Funktion wünschen", "Pedir una función nueva", "Proposer une fonctionnalité", "Chiedi una nuova funzione", "新機能をリクエスト", "Sugerir um recurso")
add("Account", "Account", "Cuenta", "Compte", "Account", "アカウント", "Conta")
add("Delete My Account", "Account löschen", "Eliminar mi cuenta", "Supprimer mon compte", "Elimina il mio account", "アカウントを削除", "Excluir minha conta")
add("Delete My Account?", "Account löschen?", "¿Eliminar mi cuenta?", "Supprimer mon compte ?", "Eliminare il mio account?", "アカウントを削除しますか？", "Excluir minha conta?")
add("Delete My Account Data", "Accountdaten löschen", "Eliminar los datos de mi cuenta", "Supprimer les données de mon compte", "Elimina i dati del mio account", "アカウントのデータを削除", "Excluir os dados da minha conta")
add(
    "This will permanently delete your wishlists, children, purchases, friends, and account from North Pole. This cannot be undone.",
    "Dadurch werden deine Wunschlisten, Kinder, Käufe, Freunde und dein Account endgültig aus North Pole gelöscht. Das lässt sich nicht rückgängig machen.",
    "Esto eliminará de forma permanente tus listas, niños, compras, amigos y tu cuenta de North Pole. No se puede deshacer.",
    "Cette action supprimera définitivement vos listes, enfants, achats, amis et votre compte de North Pole. Elle est irréversible.",
    "Questa operazione eliminerà definitivamente le tue liste, i bambini, gli acquisti, gli amici e il tuo account da North Pole. Non è reversibile.",
    "North Pole からウィッシュリスト、子ども、購入履歴、友だち、アカウントが完全に削除されます。この操作は取り消せません。",
    "Isso excluirá permanentemente suas listas, crianças, compras, amigos e sua conta do North Pole. Não é possível desfazer.",
)
add(
    "Are you sure? This permanently removes your North Pole data. Other users’ data will not be affected.",
    "Bist du sicher? Deine North-Pole-Daten werden endgültig entfernt. Daten anderer Nutzer bleiben unberührt.",
    "¿Seguro? Se eliminarán de forma permanente tus datos de North Pole. Los datos de otros usuarios no se verán afectados.",
    "Confirmer ? Vos données North Pole seront définitivement supprimées. Les données des autres utilisateurs ne seront pas touchées.",
    "Vuoi procedere? I tuoi dati di North Pole verranno rimossi definitivamente. I dati degli altri utenti non saranno toccati.",
    "本当によろしいですか？ North Pole のデータが完全に削除されます。他のユーザーのデータには影響しません。",
    "Tem certeza? Seus dados do North Pole serão removidos permanentemente. Os dados de outros usuários não serão afetados.",
)
add(
    "Not signed in. Please sign in before deleting your account.",
    "Nicht angemeldet. Melde dich an, bevor du deinen Account löschst.",
    "No has iniciado sesión. Inicia sesión antes de eliminar tu cuenta.",
    "Vous n’êtes pas connecté. Connectez-vous avant de supprimer votre compte.",
    "Non hai effettuato l’accesso. Accedi prima di eliminare il tuo account.",
    "サインインしていません。アカウントを削除する前にサインインしてください。",
    "Você não está conectado. Faça login antes de excluir sua conta.",
)
add(
    "Your account and data were deleted.",
    "Dein Account und deine Daten wurden gelöscht.",
    "Tu cuenta y tus datos se han eliminado.",
    "Votre compte et vos données ont été supprimés.",
    "Il tuo account e i tuoi dati sono stati eliminati.",
    "アカウントとデータを削除しました。",
    "Sua conta e seus dados foram excluídos.",
)
add(
    "Failed to delete account data: %@",
    "Accountdaten konnten nicht gelöscht werden: %@",
    "No se pudieron eliminar los datos de la cuenta: %@",
    "Impossible de supprimer les données du compte : %@",
    "Impossibile eliminare i dati dell’account: %@",
    "アカウントデータを削除できませんでした：%@",
    "Não foi possível excluir os dados da conta: %@",
)
add("Legal", "Rechtliches", "Legal", "Mentions légales", "Note legali", "法的情報", "Jurídico")
add("Privacy Policy", "Datenschutzrichtlinie", "Política de privacidad", "Politique de confidentialité", "Informativa sulla privacy", "プライバシーポリシー", "Política de Privacidade")
add("North Pole v%@", "North Pole v%@", "North Pole v%@", "North Pole v%@", "North Pole v%@", "North Pole v%@", "North Pole v%@")
add(
    "Made with ❄️ in Atlanta",
    "Mit ❄️ gemacht in Atlanta",
    "Hecho con ❄️ en Atlanta",
    "Conçu avec ❄️ à Atlanta",
    "Fatto con ❄️ ad Atlanta",
    "アトランタで ❄️ を込めて",
    "Feito com ❄️ em Atlanta",
)
add("Notifications Disabled", "Mitteilungen deaktiviert", "Notificaciones desactivadas", "Notifications désactivées", "Notifiche disattivate", "通知がオフです", "Notificações desativadas")
add("Open Settings", "Einstellungen öffnen", "Abrir Ajustes", "Ouvrir Réglages", "Apri Impostazioni", "設定を開く", "Abrir Ajustes")
add(
    "Notification permissions were denied. Please enable them in Settings to receive purchase notifications.",
    "Die Berechtigung für Mitteilungen wurde abgelehnt. Aktiviere sie in den Einstellungen, um Mitteilungen zu Käufen zu erhalten.",
    "Se han denegado los permisos de notificación. Actívalos en Ajustes para recibir notificaciones de compra.",
    "L’autorisation des notifications a été refusée. Activez-la dans Réglages pour recevoir les notifications d’achat.",
    "L’autorizzazione alle notifiche è stata negata. Attivala in Impostazioni per ricevere le notifiche di acquisto.",
    "通知が許可されていません。購入の通知を受け取るには「設定」で許可してください。",
    "As permissões de notificação foram negadas. Ative-as em Ajustes para receber notificações de compra.",
)
add("North Pole - Bug Report", "North Pole – Fehlerbericht", "North Pole: informe de error", "North Pole – Signalement de bug", "North Pole – Segnalazione di un problema", "North Pole - 不具合の報告", "North Pole - Relato de erro")
add(
    "Please describe the bug you encountered:\n\n\n\n---\nApp Version: %@\nDevice: %@\niOS Version: %@",
    "Bitte beschreibe den Fehler, den du gefunden hast:\n\n\n\n---\nApp-Version: %@\nGerät: %@\niOS-Version: %@",
    "Describe el error que encontraste:\n\n\n\n---\nVersión de la app: %@\nDispositivo: %@\nVersión de iOS: %@",
    "Décrivez le bug que vous avez rencontré :\n\n\n\n---\nVersion de l’app : %@\nAppareil : %@\nVersion d’iOS : %@",
    "Descrivi il problema che hai riscontrato:\n\n\n\n---\nVersione dell’app: %@\nDispositivo: %@\nVersione di iOS: %@",
    "発生した不具合の内容をご記入ください：\n\n\n\n---\nアプリのバージョン: %@\nデバイス: %@\niOS のバージョン: %@",
    "Descreva o erro que você encontrou:\n\n\n\n---\nVersão do app: %@\nDispositivo: %@\nVersão do iOS: %@",
)
add("North Pole - Feature Request", "North Pole – Funktionswunsch", "North Pole: sugerencia de función", "North Pole – Suggestion de fonctionnalité", "North Pole – Richiesta di funzione", "North Pole - 機能のリクエスト", "North Pole - Sugestão de recurso")
add(
    "Hi,\n\nThis is a user-driven product and we value your feedback! What feature would you like to see?\n\n\n\n---\nApp Version: %@\nDevice: %@\niOS Version: %@",
    "Hallo,\n\nDiese App lebt von ihren Nutzern und wir freuen uns über dein Feedback! Welche Funktion würdest du dir wünschen?\n\n\n\n---\nApp-Version: %@\nGerät: %@\niOS-Version: %@",
    "Hola:\n\n¡Esta app la construimos con quienes la usan y tu opinión nos importa! ¿Qué función te gustaría ver?\n\n\n\n---\nVersión de la app: %@\nDispositivo: %@\nVersión de iOS: %@",
    "Bonjour,\n\nCette app est façonnée par ses utilisateurs et votre avis compte ! Quelle fonctionnalité aimeriez-vous voir ?\n\n\n\n---\nVersion de l’app : %@\nAppareil : %@\nVersion d’iOS : %@",
    "Ciao,\n\nQuesta app cresce grazie a chi la usa e il tuo parere conta! Quale funzione ti piacerebbe vedere?\n\n\n\n---\nVersione dell’app: %@\nDispositivo: %@\nVersione di iOS: %@",
    "こんにちは。\n\nこのアプリは使ってくださる方の声で育っています。追加してほしい機能があれば教えてください。\n\n\n\n---\nアプリのバージョン: %@\nデバイス: %@\niOS のバージョン: %@",
    "Olá,\n\nEste app é feito com quem usa e sua opinião importa! Qual recurso você gostaria de ver?\n\n\n\n---\nVersão do app: %@\nDispositivo: %@\nVersão do iOS: %@",
)

# --- My wishlist ------------------------------------------------------------
add("Me", "Ich", "Yo", "Moi", "Io", "自分", "Eu")
add(
    "Tap the + button to add items\nto your wishlist",
    "Tippe auf +, um Wünsche\nzu deiner Liste hinzuzufügen",
    "Toca + para añadir artículos\na tu lista",
    "Touchez + pour ajouter des articles\nà votre liste",
    "Tocca + per aggiungere articoli\nalla tua lista",
    "＋ をタップして\nリストにアイテムを追加",
    "Toque em + para adicionar itens\nà sua lista",
)
add("Checked off", "Abgehakt", "Marcado", "Coché", "Spuntato", "チェック済み", "Marcado")
add("Unpurchase", "Nicht mehr gekauft", "Desmarcar", "Décocher", "Annulla acquisto", "購入を取り消す", "Desmarcar")
add("Mark as Purchased", "Als gekauft markieren", "Marcar como comprado", "Marquer comme acheté", "Segna come acquistato", "購入済みにする", "Marcar como comprado")
add("View Item", "Artikel ansehen", "Ver artículo", "Voir l’article", "Vedi articolo", "商品を見る", "Ver item")
add("Delete Item", "Wunsch löschen", "Eliminar artículo", "Supprimer l’article", "Elimina articolo", "アイテムを削除", "Excluir item")
add(
    "Are you sure you want to delete '%@'?",
    "Möchtest du „%@“ wirklich löschen?",
    "¿Seguro que quieres eliminar «%@»?",
    "Voulez-vous vraiment supprimer « %@ » ?",
    "Vuoi davvero eliminare «%@»?",
    "「%@」を削除してもよろしいですか？",
    "Tem certeza de que deseja excluir “%@”?",
)
add(
    "Please sign in to continue",
    "Bitte melde dich an, um fortzufahren",
    "Inicia sesión para continuar",
    "Connectez-vous pour continuer",
    "Accedi per continuare",
    "続けるにはサインインしてください",
    "Faça login para continuar",
)
add("Failed to sync: %@", "Synchronisierung fehlgeschlagen: %@", "No se pudo sincronizar: %@", "Échec de la synchronisation : %@", "Sincronizzazione non riuscita: %@", "同期できませんでした：%@", "Falha na sincronização: %@")
add(
    "Send to Friends",
    "An Freunde senden",
    "Enviar a amigos",
    "Envoyer à des amis",
    "Invia agli amici",
    "友だちに送る",
    "Enviar aos amigos",
)
# %@ order is title then item list — keep it identical in every language.
add(
    "Hi! Would you like to do a gift exchange? Build your list here and we can sync up.\n\n%@\n%@\n\nGet the app: https://apps.apple.com/app/id6755366177",
    "Hi! Hast du Lust, Geschenke zu tauschen? Erstelle hier deine Liste, dann stimmen wir uns ab.\n\n%@\n%@\n\nHol dir die App: https://apps.apple.com/app/id6755366177",
    "¡Hola! ¿Te apetece un intercambio de regalos? Crea tu lista aquí y nos coordinamos.\n\n%@\n%@\n\nDescarga la app: https://apps.apple.com/app/id6755366177",
    "Salut ! Ça te dit d’échanger des cadeaux ? Crée ta liste ici et on se coordonne.\n\n%@\n%@\n\nTélécharge l’app : https://apps.apple.com/app/id6755366177",
    "Ciao! Ti va di scambiarci i regali? Crea la tua lista qui e ci coordiniamo.\n\n%@\n%@\n\nScarica l’app: https://apps.apple.com/app/id6755366177",
    "こんにちは！プレゼント交換しませんか？ここでリストを作れば、お互いに確認できます。\n\n%@\n%@\n\nアプリはこちら: https://apps.apple.com/app/id6755366177",
    "Oi! Quer fazer uma troca de presentes? Monte sua lista aqui e a gente se organiza.\n\n%@\n%@\n\nBaixe o app: https://apps.apple.com/app/id6755366177",
)

# --- Add gift ---------------------------------------------------------------
add("Item Name", "Bezeichnung", "Nombre del artículo", "Nom de l’article", "Nome dell’articolo", "アイテム名", "Nome do item")
add("e.g., Coffee Maker", "z. B. Kaffeemaschine", "Ej.: cafetera", "Ex. : cafetière", "Es.: macchina del caffè", "例：コーヒーメーカー", "Ex.: cafeteira")
add("Cleaning title...", "Titel wird gekürzt …", "Depurando el título…", "Nettoyage du titre…", "Pulizia del titolo…", "タイトルを整理中…", "Ajustando o título…")
add("Link", "Link", "Enlace", "Lien", "Link", "リンク", "Link")
add("Paste", "Einsetzen", "Pegar", "Coller", "Incolla", "ペースト", "Colar")
add("Extracting product info...", "Produktinfos werden geladen …", "Obteniendo datos del producto…", "Récupération des infos produit…", "Recupero delle info sul prodotto…", "商品情報を取得中…", "Buscando informações do produto…")
add("Description", "Beschreibung", "Descripción", "Description", "Descrizione", "説明", "Descrição")
add(
    "Add any notes or preferences...",
    "Notizen oder Wünsche hinzufügen …",
    "Añade notas o preferencias…",
    "Ajoutez des notes ou des préférences…",
    "Aggiungi note o preferenze…",
    "メモや希望を追加…",
    "Adicione notas ou preferências…",
)
add("Photo", "Foto", "Foto", "Photo", "Foto", "写真", "Foto")
add("Change Photo", "Foto ändern", "Cambiar foto", "Changer la photo", "Cambia foto", "写真を変更", "Alterar foto")
add("Delete Gift", "Geschenk löschen", "Eliminar regalo", "Supprimer le cadeau", "Elimina il regalo", "ギフトを削除", "Excluir presente")
add("Add Gift", "Geschenk hinzufügen", "Añadir regalo", "Ajouter un cadeau", "Aggiungi un regalo", "ギフトを追加", "Adicionar presente")
add("Edit Gift", "Geschenk bearbeiten", "Editar regalo", "Modifier le cadeau", "Modifica il regalo", "ギフトを編集", "Editar presente")
add(
    "Adding items\nto your wishlist",
    "Wünsche zu deiner\nListe hinzufügen",
    "Añadir artículos\na tu lista",
    "Ajouter des articles\nà votre liste",
    "Aggiungere articoli\nalla tua lista",
    "リストにアイテムを\n追加する",
    "Adicionar itens\nà sua lista",
)
add("Price: %@", "Preis: %@", "Precio: %@", "Prix : %@", "Prezzo: %@", "価格：%@", "Preço: %@")
add(
    "Child account not properly synced. Please try again.",
    "Das Kinderprofil wurde nicht vollständig synchronisiert. Bitte versuche es erneut.",
    "El perfil del niño no se sincronizó correctamente. Inténtalo de nuevo.",
    "Le profil de l’enfant n’a pas été synchronisé correctement. Réessayez.",
    "Il profilo del bambino non è stato sincronizzato correttamente. Riprova.",
    "子どものプロフィールを正しく同期できませんでした。もう一度お試しください。",
    "O perfil da criança não foi sincronizado corretamente. Tente novamente.",
)

# --- Friends ----------------------------------------------------------------
add("Remove Friend", "Freund entfernen", "Eliminar amigo", "Retirer l’ami", "Rimuovi amico", "友だちを削除", "Remover amigo")
add("Remove", "Entfernen", "Eliminar", "Retirer", "Rimuovi", "削除", "Remover")
add("Hide", "Ausblenden", "Ocultar", "Masquer", "Nascondi", "非表示", "Ocultar")
add("Hide Child", "Kind ausblenden", "Ocultar niño", "Masquer l’enfant", "Nascondi il bambino", "子どもを非表示", "Ocultar criança")
add("No friends added yet", "Noch keine Freunde", "Aún no hay amigos", "Aucun ami pour l’instant", "Ancora nessun amico", "友だちはまだいません", "Nenhum amigo ainda")
add(
    "Tap the + button to add friends\nfrom your contacts",
    "Tippe auf +, um Freunde\naus deinen Kontakten hinzuzufügen",
    "Toca + para añadir amigos\ndesde tus contactos",
    "Touchez + pour ajouter des amis\ndepuis vos contacts",
    "Tocca + per aggiungere amici\ndai tuoi contatti",
    "＋ をタップして\n連絡先から友だちを追加",
    "Toque em + para adicionar amigos\ndos seus contatos",
)
add("Loading friends...", "Freunde werden geladen …", "Cargando amigos…", "Chargement des amis…", "Caricamento amici…", "友だちを読み込み中…", "Carregando amigos…")
add(
    "%@ is already in your friends list",
    "%@ ist bereits in deiner Freundesliste",
    "%@ ya está en tu lista de amigos",
    "%@ figure déjà dans votre liste d’amis",
    "%@ è già nella tua lista di amici",
    "%@ はすでに友だちリストにいます",
    "%@ já está na sua lista de amigos",
)
add(
    "Failed to save friend: %@",
    "Freund konnte nicht gesichert werden: %@",
    "No se pudo guardar el amigo: %@",
    "Impossible d’enregistrer l’ami : %@",
    "Impossibile salvare l’amico: %@",
    "友だちを保存できませんでした：%@",
    "Não foi possível salvar o amigo: %@",
)
add(
    "Checking if friend has app...",
    "Wird geprüft, ob dein Freund die App hat …",
    "Comprobando si tu amigo tiene la app…",
    "Vérification de l’installation de l’app…",
    "Verifica se il tuo amico ha l’app…",
    "友だちがアプリを持っているか確認中…",
    "Verificando se seu amigo tem o app…",
)
add("Invite %@", "%@ einladen", "Invitar a %@", "Inviter %@", "Invita %@", "%@ を招待", "Convidar %@")
add("Mark %@ as purchased?", "„%@“ als gekauft markieren?", "¿Marcar «%@» como comprado?", "Marquer « %@ » comme acheté ?", "Segnare «%@» come acquistato?", "「%@」を購入済みにしますか？", "Marcar “%@” como comprado?")
add("Mark %@ as unpurchased?", "Markierung für „%@“ aufheben?", "¿Desmarcar «%@» como comprado?", "Décocher « %@ » comme acheté ?", "Rimuovere l’acquisto di «%@»?", "「%@」の購入済みを取り消しますか？", "Desmarcar “%@” como comprado?")
add("Mark item as purchased?", "Artikel als gekauft markieren?", "¿Marcar el artículo como comprado?", "Marquer l’article comme acheté ?", "Segnare l’articolo come acquistato?", "このアイテムを購入済みにしますか？", "Marcar o item como comprado?")
add("Unmark", "Aufheben", "Desmarcar", "Décocher", "Rimuovi", "取り消す", "Desmarcar")
add("Purchased", "Gekauft", "Comprado", "Acheté", "Acquistato", "購入済み", "Comprado")
add(
    "%@ has not installed this app yet",
    "%@ hat die App noch nicht installiert",
    "%@ todavía no ha instalado la app",
    "%@ n’a pas encore installé l’app",
    "%@ non ha ancora installato l’app",
    "%@ はまだこのアプリを使っていません",
    "%@ ainda não instalou o app",
)
add(
    "%@ hasn't added\nanything to their wishlist",
    "%@ hat noch nichts\nauf die Wunschliste gesetzt",
    "%@ aún no ha añadido\nnada a su lista",
    "%@ n’a encore rien ajouté\nà sa liste",
    "%@ non ha ancora aggiunto\nnulla alla sua lista",
    "%@ はまだリストに\n何も追加していません",
    "%@ ainda não adicionou\nnada à lista",
)
add("Visit Link", "Link öffnen", "Abrir enlace", "Ouvrir le lien", "Apri il link", "リンクを開く", "Abrir link")
add("Unpurchase Item", "Kauf zurücknehmen", "Desmarcar artículo", "Décocher l’article", "Annulla l’acquisto", "購入を取り消す", "Desmarcar item")
add(
    "Failed to update item: %@",
    "Artikel konnte nicht aktualisiert werden: %@",
    "No se pudo actualizar el artículo: %@",
    "Impossible de mettre à jour l’article : %@",
    "Impossibile aggiornare l’articolo: %@",
    "アイテムを更新できませんでした：%@",
    "Não foi possível atualizar o item: %@",
)
add(
    "I have a wishlist here if you are interested. I would like to see yours as well.\n\nGet the app: https://apps.apple.com/app/id6755366177",
    "Falls es dich interessiert: Hier ist meine Wunschliste. Deine würde ich auch gern sehen.\n\nHol dir die App: https://apps.apple.com/app/id6755366177",
    "Por si te interesa, aquí está mi lista de deseos. Me encantaría ver la tuya también.\n\nDescarga la app: https://apps.apple.com/app/id6755366177",
    "Si ça t’intéresse, voici ma liste de souhaits. J’aimerais bien voir la tienne aussi.\n\nTélécharge l’app : https://apps.apple.com/app/id6755366177",
    "Se ti va, ecco la mia lista dei desideri. Mi piacerebbe vedere anche la tua.\n\nScarica l’app: https://apps.apple.com/app/id6755366177",
    "よかったら私のほしい物リストを見てね。あなたのリストも見せてほしいな。\n\nアプリはこちら: https://apps.apple.com/app/id6755366177",
    "Se tiver interesse, esta é a minha lista de desejos. Também adoraria ver a sua.\n\nBaixe o app: https://apps.apple.com/app/id6755366177",
)

# --- Ask Santa --------------------------------------------------------------
add(
    "I know what people want in %@!",
    "Ich weiß, was man sich %@ wünscht!",
    "¡Sé lo que la gente quiere en %@!",
    "Je sais ce que l’on souhaite en %@ !",
    "So che cosa si desidera nel %@!",
    "%@年に人気のものを知っているよ！",
    "Eu sei o que as pessoas querem em %@!",
)
add("Age", "Alter", "Edad", "Âge", "Età", "年齢", "Idade")
add("Enter age", "Alter eingeben", "Introduce la edad", "Saisir l’âge", "Inserisci l’età", "年齢を入力", "Digite a idade")
add("Gender", "Geschlecht", "Género", "Genre", "Genere", "性別", "Gênero")
add("Male", "Männlich", "Masculino", "Homme", "Uomo", "男性", "Masculino")
add("Female", "Weiblich", "Femenino", "Femme", "Donna", "女性", "Feminino")
add("Either", "Egal", "Cualquiera", "Peu importe", "Indifferente", "指定なし", "Tanto faz")
add("Budget", "Budget", "Presupuesto", "Budget", "Budget", "予算", "Orçamento")
add("Gift Type", "Art des Geschenks", "Tipo de regalo", "Type de cadeau", "Tipo di regalo", "ギフトのタイプ", "Tipo de presente")
add("Fun & Entertainment", "Spaß & Unterhaltung", "Diversión", "Divertissement", "Divertimento", "楽しさ重視", "Diversão")
add("Mostly Fun", "Eher Spaß", "Más diversión", "Plutôt ludique", "Più divertente", "やや楽しさ重視", "Mais diversão")
add("Balanced", "Ausgewogen", "Equilibrado", "Équilibré", "Equilibrato", "バランス", "Equilibrado")
add("Mostly Educational", "Eher lehrreich", "Más educativo", "Plutôt éducatif", "Più educativo", "やや学び重視", "Mais educativo")
add("Highly Educational", "Sehr lehrreich", "Muy educativo", "Très éducatif", "Molto educativo", "学び重視", "Muito educativo")
add("Interests", "Interessen", "Intereses", "Centres d’intérêt", "Interessi", "興味", "Interesses")
add("%lld/%lld", "%lld/%lld", "%lld/%lld", "%lld/%lld", "%lld/%lld", "%lld/%lld", "%lld/%lld")
add("Find Gift Ideas", "Geschenkideen finden", "Buscar ideas de regalo", "Trouver des idées", "Trova idee regalo", "ギフトのアイデアを探す", "Buscar ideias de presente")
add("Find More", "Mehr finden", "Buscar más", "En trouver d’autres", "Trova altre idee", "もっと探す", "Buscar mais")
add("Searching for gift ideas", "Geschenkideen werden gesucht", "Buscando ideas de regalo", "Recherche d’idées de cadeaux", "Ricerca di idee regalo", "ギフトのアイデアを検索中", "Buscando ideias de presente")
add("No gift ideas found", "Keine Geschenkideen gefunden", "No se encontraron ideas", "Aucune idée trouvée", "Nessuna idea trovata", "ギフトのアイデアが見つかりません", "Nenhuma ideia encontrada")
add(
    "Try adjusting your search criteria",
    "Passe deine Suchkriterien an",
    "Prueba a ajustar los criterios de búsqueda",
    "Essayez d’ajuster vos critères",
    "Prova a modificare i criteri di ricerca",
    "検索条件を変えてみてください",
    "Tente ajustar os critérios de busca",
)
add(
    "Santa couldn't reach the workshop",
    "Der Weihnachtsmann ist nicht erreichbar",
    "Papá Noel no pudo contactar con el taller",
    "Le Père Noël n’a pas pu joindre l’atelier",
    "Babbo Natale non è riuscito a contattare la bottega",
    "サンタは工房と連絡が取れませんでした",
    "O Papai Noel não conseguiu falar com a oficina",
)
add(
    "AI suggestions require API configuration",
    "Für KI-Vorschläge fehlt die API-Konfiguration",
    "Las sugerencias con IA requieren configurar la API",
    "Les suggestions IA nécessitent une configuration de l’API",
    "I suggerimenti AI richiedono la configurazione dell’API",
    "AI 提案には API の設定が必要です",
    "As sugestões com IA exigem configuração da API",
)
add("Invalid API URL", "Ungültige API-URL", "URL de la API no válida", "URL d’API non valide", "URL dell’API non valido", "API の URL が正しくありません", "URL da API inválido")
add(
    "API returned error code %lld",
    "Die API hat den Fehlercode %lld zurückgegeben",
    "La API devolvió el código de error %lld",
    "L’API a renvoyé le code d’erreur %lld",
    "L’API ha restituito il codice di errore %lld",
    "API がエラーコード %lld を返しました",
    "A API retornou o código de erro %lld",
)
add(
    "Failed to parse API response",
    "Antwort der API konnte nicht gelesen werden",
    "No se pudo interpretar la respuesta de la API",
    "Impossible de lire la réponse de l’API",
    "Impossibile leggere la risposta dell’API",
    "API の応答を解析できませんでした",
    "Não foi possível interpretar a resposta da API",
)
add(
    "Santa couldn't read the reply. Please try again.",
    "Der Weihnachtsmann konnte die Antwort nicht lesen. Bitte versuche es erneut.",
    "Papá Noel no pudo leer la respuesta. Inténtalo de nuevo.",
    "Le Père Noël n’a pas pu lire la réponse. Réessayez.",
    "Babbo Natale non è riuscito a leggere la risposta. Riprova.",
    "サンタは返事を読み取れませんでした。もう一度お試しください。",
    "O Papai Noel não conseguiu ler a resposta. Tente novamente.",
)
add(
    "Santa's most requested",
    "Die häufigsten Wünsche",
    "Lo más pedido a Papá Noel",
    "Les plus demandés au Père Noël",
    "I più richiesti a Babbo Natale",
    "サンタへの人気リクエスト",
    "Os mais pedidos ao Papai Noel",
)

# Looked up at runtime via LocalizedStringKey(rawValue), so the build-time
# extractor never sees them — they must be pinned as manually managed.
MANUAL = {
    "Male", "Female", "Either",
    "Camping & Outdoors", "Lego", "Videogames", "Cooking", "Grilling", "Smart Home",
    "Reading & Books", "Sports & Fitness", "Arts & Crafts",
    "Technology & Gadgets", "Fashion & Accessories", "Home & Garden", "Travel",
    "Photography", "Board Games & Puzzles", "DIY & Tools", "Beauty & Self-Care",
    "Stuff for Dogs", "Collectibles & Memorabilia", "Coffee & Tea",
}

# Interest chips. Sent to xAI in English; only the label is translated.
add("Camping & Outdoors", "Camping & Outdoor", "Camping y aire libre", "Camping et plein air", "Campeggio e outdoor", "キャンプ・アウトドア", "Camping e ar livre")
add("Lego", "Lego", "Lego", "Lego", "Lego", "レゴ", "Lego")
add("Videogames", "Videospiele", "Videojuegos", "Jeux vidéo", "Videogiochi", "ゲーム", "Videogames")
add("Cooking", "Kochen", "Cocina", "Cuisine", "Cucina", "料理", "Culinária")
add("Grilling", "Grillen", "Barbacoa", "Barbecue", "Barbecue", "バーベキュー", "Churrasco")
add("Smart Home", "Smart Home", "Casa inteligente", "Maison connectée", "Casa intelligente", "スマートホーム", "Casa inteligente")
add("Reading & Books", "Lesen & Bücher", "Lectura y libros", "Lecture et livres", "Lettura e libri", "読書・本", "Leitura e livros")
add("Sports & Fitness", "Sport & Fitness", "Deporte y fitness", "Sport et fitness", "Sport e fitness", "スポーツ・フィットネス", "Esporte e fitness")
add("Arts & Crafts", "Kunst & Basteln", "Manualidades", "Arts et loisirs créatifs", "Arte e fai da te", "アート・手芸", "Arte e artesanato")
add("Technology & Gadgets", "Technik & Gadgets", "Tecnología y gadgets", "Tech et gadgets", "Tecnologia e gadget", "テクノロジー・ガジェット", "Tecnologia e gadgets")
add("Fashion & Accessories", "Mode & Accessoires", "Moda y accesorios", "Mode et accessoires", "Moda e accessori", "ファッション・小物", "Moda e acessórios")
add("Home & Garden", "Haus & Garten", "Hogar y jardín", "Maison et jardin", "Casa e giardino", "住まい・ガーデニング", "Casa e jardim")
add("Travel", "Reisen", "Viajes", "Voyage", "Viaggi", "旅行", "Viagem")
add("Photography", "Fotografie", "Fotografía", "Photographie", "Fotografia", "写真", "Fotografia")
add("Board Games & Puzzles", "Brettspiele & Puzzles", "Juegos de mesa y puzles", "Jeux de société et puzzles", "Giochi da tavolo e puzzle", "ボードゲーム・パズル", "Jogos de tabuleiro e quebra-cabeças")
add("DIY & Tools", "Heimwerken & Werkzeug", "Bricolaje y herramientas", "Bricolage et outils", "Bricolage e utensili", "DIY・工具", "Faça você mesmo e ferramentas")
add("Beauty & Self-Care", "Beauty & Pflege", "Belleza y autocuidado", "Beauté et bien-être", "Bellezza e cura di sé", "ビューティー・セルフケア", "Beleza e autocuidado")
add("Stuff for Dogs", "Für Hunde", "Cosas para perros", "Pour les chiens", "Cose per cani", "犬のためのもの", "Coisas para cães")
add("Collectibles & Memorabilia", "Sammlerstücke", "Coleccionables", "Objets de collection", "Da collezione", "コレクション", "Colecionáveis")
add("Coffee & Tea", "Kaffee & Tee", "Café y té", "Café et thé", "Caffè e tè", "コーヒー・お茶", "Café e chá")

# --- Onboarding -------------------------------------------------------------
add(
    "Welcome!\nCan I ask for some help? ",
    "Willkommen!\nDarf ich dich um Hilfe bitten? ",
    "¡Bienvenido!\n¿Me echas una mano? ",
    "Bienvenue !\nPuis-je vous demander un coup de main ? ",
    "Benvenuto!\nPosso chiederti una mano? ",
    "ようこそ！\nちょっと手伝ってくれるかな？ ",
    "Bem-vindo!\nPosso pedir uma ajudinha? ",
)
add(
    "Please select everyone that you\nmay exchange gifts with.",
    "Wähle alle aus, mit denen du\nvielleicht Geschenke tauschst.",
    "Selecciona a todas las personas con\nlas que puedas intercambiar regalos.",
    "Sélectionnez toutes les personnes avec\nqui vous pourriez échanger des cadeaux.",
    "Seleziona tutte le persone con cui\npotresti scambiare dei regali.",
    "ギフトを交換するかもしれない人を\nすべて選んでください。",
    "Selecione todas as pessoas com quem\nvocê pode trocar presentes.",
)
add("Select Friends", "Freunde auswählen", "Seleccionar amigos", "Sélectionner des amis", "Seleziona amici", "友だちを選ぶ", "Selecionar amigos")
add("Skip for now", "Später", "Ahora no", "Plus tard", "Non ora", "あとで", "Agora não")
add(
    "Would you like to add your kids (without a phone) to the gift exchange?",
    "Möchtest du deine Kinder (ohne eigenes Handy) zum Geschenketausch hinzufügen?",
    "¿Quieres añadir a tus hijos (sin teléfono) al intercambio de regalos?",
    "Souhaitez-vous ajouter vos enfants (sans téléphone) à l’échange de cadeaux ?",
    "Vuoi aggiungere i tuoi bambini (senza telefono) allo scambio di regali?",
    "スマホを持たないお子さんもギフト交換に追加しますか？",
    "Quer adicionar seus filhos (sem celular) à troca de presentes?",
)
add("Add a Child", "Kind hinzufügen", "Añadir un niño", "Ajouter un enfant", "Aggiungi un bambino", "子どもを追加", "Adicionar uma criança")
add("Adding children...", "Kinder werden hinzugefügt …", "Añadiendo niños…", "Ajout des enfants…", "Aggiunta dei bambini…", "子どもを追加中…", "Adicionando crianças…")
add(
    "Would you like to know if items are checked off your list?",
    "Möchtest du sehen, wenn Wünsche von deiner Liste abgehakt werden?",
    "¿Quieres saber cuándo se marcan artículos de tu lista?",
    "Souhaitez-vous savoir quand des articles de votre liste sont cochés ?",
    "Vuoi sapere quando gli articoli della tua lista vengono spuntati?",
    "リストのアイテムがチェックされたことを知りたいですか？",
    "Você quer saber quando itens da sua lista forem marcados?",
)
add("I like surprises!", "Ich mag Überraschungen!", "¡Me gustan las sorpresas!", "J’aime les surprises !", "Amo le sorprese!", "サプライズが好き！", "Eu gosto de surpresas!")
add("I don't like surprises.", "Ich mag keine Überraschungen.", "No me gustan las sorpresas.", "Je n’aime pas les surprises.", "Non amo le sorprese.", "サプライズは苦手。", "Não gosto de surpresas.")
add(
    "Adding items from the web\nto your wishlist",
    "Wünsche aus dem Web\nzu deiner Liste hinzufügen",
    "Añadir artículos de la web\na tu lista",
    "Ajouter des articles du web\nà votre liste",
    "Aggiungere articoli dal web\nalla tua lista",
    "ウェブからアイテムを\nリストに追加する",
    "Adicionar itens da web\nà sua lista",
)
add("Get Started", "Los geht’s", "Empezar", "Commencer", "Iniziamo", "はじめる", "Começar")

# --- Manage children --------------------------------------------------------
add("Loading children...", "Kinder werden geladen …", "Cargando niños…", "Chargement des enfants…", "Caricamento bambini…", "子どもを読み込み中…", "Carregando crianças…")
add(
    "Add children who don't have their own phone so you can manage their wishlists. When friends add you, they'll see your children too.",
    "Füge Kinder ohne eigenes Handy hinzu, damit du ihre Wunschlisten verwalten kannst. Wenn Freunde dich hinzufügen, sehen sie auch deine Kinder.",
    "Añade niños que no tienen teléfono propio para gestionar sus listas. Cuando tus amigos te añadan, también verán a tus hijos.",
    "Ajoutez les enfants qui n’ont pas de téléphone pour gérer leurs listes. Lorsque vos amis vous ajoutent, ils voient aussi vos enfants.",
    "Aggiungi i bambini che non hanno un telefono per gestire le loro liste. Quando gli amici ti aggiungono, vedranno anche i tuoi bambini.",
    "自分のスマホを持たない子どもを追加すると、そのウィッシュリストを管理できます。友だちがあなたを追加すると、子どものリストも表示されます。",
    "Adicione crianças que não têm celular para gerenciar as listas delas. Quando seus amigos adicionarem você, verão suas crianças também.",
)
add("No children added yet", "Noch keine Kinder", "Aún no hay niños", "Aucun enfant pour l’instant", "Ancora nessun bambino", "子どもはまだ追加されていません", "Nenhuma criança ainda")
add("Delete Child", "Kind löschen", "Eliminar niño", "Supprimer l’enfant", "Elimina il bambino", "子どもを削除", "Excluir criança")
add(
    "Are you sure you want to delete %@? This will also delete all their wishlist items.",
    "Möchtest du %@ wirklich löschen? Dabei werden auch alle Wünsche gelöscht.",
    "¿Seguro que quieres eliminar a %@? También se eliminarán todos sus artículos.",
    "Voulez-vous vraiment supprimer %@ ? Tous ses articles seront également supprimés.",
    "Vuoi davvero eliminare %@? Verranno eliminati anche tutti i suoi articoli.",
    "%@ を削除してもよろしいですか？ ウィッシュリストのアイテムもすべて削除されます。",
    "Tem certeza de que deseja excluir %@? Todos os itens da lista também serão excluídos.",
)
add("Child's name", "Name des Kindes", "Nombre del niño", "Prénom de l’enfant", "Nome del bambino", "子どもの名前", "Nome da criança")
add("Add Child", "Kind hinzufügen", "Añadir niño", "Ajouter un enfant", "Aggiungi bambino", "子どもを追加", "Adicionar criança")

# --- Phone auth -------------------------------------------------------------
add(
    "Welcome to\nChristmas Wishlist",
    "Willkommen bei\nChristmas Wishlist",
    "Te damos la bienvenida a\nChristmas Wishlist",
    "Bienvenue sur\nChristmas Wishlist",
    "Ti diamo il benvenuto su\nChristmas Wishlist",
    "Christmas Wishlist へ\nようこそ",
    "Boas-vindas ao\nChristmas Wishlist",
)
add(
    "Sign in with your phone number to get started",
    "Melde dich mit deiner Telefonnummer an, um loszulegen",
    "Inicia sesión con tu número de teléfono para empezar",
    "Connectez-vous avec votre numéro de téléphone pour commencer",
    "Accedi con il tuo numero di telefono per iniziare",
    "電話番号でサインインして始めましょう",
    "Faça login com seu número de telefone para começar",
)
add("Phone Number", "Telefonnummer", "Número de teléfono", "Numéro de téléphone", "Numero di telefono", "電話番号", "Número de telefone")
add(
    "We'll send you a verification code via SMS",
    "Wir senden dir einen Bestätigungscode per SMS",
    "Te enviaremos un código de verificación por SMS",
    "Nous vous enverrons un code de vérification par SMS",
    "Ti invieremo un codice di verifica via SMS",
    "SMS で確認コードをお送りします",
    "Enviaremos um código de verificação por SMS",
)
add("Enter Verification Code", "Bestätigungscode eingeben", "Introduce el código", "Saisir le code de vérification", "Inserisci il codice di verifica", "確認コードを入力", "Digite o código de verificação")
add("We sent a code to", "Wir haben einen Code gesendet an", "Enviamos un código a", "Nous avons envoyé un code au", "Abbiamo inviato un codice a", "コードの送信先", "Enviamos um código para")
add("6-Digit Code", "6-stelliger Code", "Código de 6 dígitos", "Code à 6 chiffres", "Codice a 6 cifre", "6桁のコード", "Código de 6 dígitos")
add("Verify & Sign In", "Bestätigen & anmelden", "Verificar e iniciar sesión", "Vérifier et se connecter", "Verifica e accedi", "確認してサインイン", "Verificar e entrar")
add(
    "Didn't receive a code? Resend",
    "Keinen Code erhalten? Erneut senden",
    "¿No recibiste el código? Reenviar",
    "Code non reçu ? Renvoyer",
    "Non hai ricevuto il codice? Invia di nuovo",
    "コードが届きませんか？ 再送信",
    "Não recebeu o código? Reenviar",
)
add(
    "Invalid phone number format. Please enter a valid 10-digit US phone number.",
    "Ungültiges Format. Bitte gib eine gültige 10-stellige US-Telefonnummer ein.",
    "Formato no válido. Introduce un número de EE. UU. de 10 dígitos.",
    "Format non valide. Saisissez un numéro américain à 10 chiffres.",
    "Formato non valido. Inserisci un numero statunitense di 10 cifre.",
    "電話番号の形式が正しくありません。10 桁の米国の番号を入力してください。",
    "Formato inválido. Digite um número dos EUA com 10 dígitos.",
)
add(
    "Failed to send verification code: %@",
    "Bestätigungscode konnte nicht gesendet werden: %@",
    "No se pudo enviar el código: %@",
    "Impossible d’envoyer le code : %@",
    "Impossibile inviare il codice: %@",
    "確認コードを送信できませんでした：%@",
    "Não foi possível enviar o código: %@",
)
add(
    "No verification ID. Please request a new code.",
    "Keine Bestätigungs-ID. Fordere einen neuen Code an.",
    "No hay ID de verificación. Solicita un código nuevo.",
    "Aucun identifiant de vérification. Demandez un nouveau code.",
    "Nessun ID di verifica. Richiedi un nuovo codice.",
    "確認 ID がありません。新しいコードをリクエストしてください。",
    "Nenhum ID de verificação. Solicite um novo código.",
)
add(
    "Invalid verification code. Please try again.",
    "Ungültiger Bestätigungscode. Bitte versuche es erneut.",
    "Código de verificación no válido. Inténtalo de nuevo.",
    "Code de vérification non valide. Réessayez.",
    "Codice di verifica non valido. Riprova.",
    "確認コードが正しくありません。もう一度お試しください。",
    "Código de verificação inválido. Tente novamente.",
)

# --- Errors -----------------------------------------------------------------
add("User is not authenticated", "Nutzer ist nicht angemeldet", "El usuario no ha iniciado sesión", "L’utilisateur n’est pas connecté", "L’utente non ha effettuato l’accesso", "サインインしていません", "O usuário não está conectado")
add("Invalid data format", "Ungültiges Datenformat", "Formato de datos no válido", "Format de données non valide", "Formato dei dati non valido", "データ形式が正しくありません", "Formato de dados inválido")
add("Network error occurred", "Netzwerkfehler", "Error de red", "Erreur réseau", "Errore di rete", "ネットワークエラーが発生しました", "Ocorreu um erro de rede")

# --- Notifications ----------------------------------------------------------
add("Gift Purchased!", "Geschenk gekauft!", "¡Regalo comprado!", "Cadeau acheté !", "Regalo acquistato!", "ギフトが購入されました！", "Presente comprado!")
add(
    "🎁 Someone purchased %@ for you!",
    "🎁 Jemand hat %@ für dich gekauft!",
    "🎁 ¡Alguien te ha comprado %@!",
    "🎁 Quelqu’un vous a acheté %@ !",
    "🎁 Qualcuno ha acquistato %@ per te!",
    "🎁 誰かがあなたに %@ を購入しました！",
    "🎁 Alguém comprou %@ para você!",
)

# --- Deep link --------------------------------------------------------------
add("Add Friend?", "Freund hinzufügen?", "¿Añadir amigo?", "Ajouter cet ami ?", "Aggiungere l’amico?", "友だちに追加しますか？", "Adicionar amigo?")
add("Add Friend", "Freund hinzufügen", "Añadir amigo", "Ajouter l’ami", "Aggiungi amico", "友だちに追加", "Adicionar amigo")
add(
    "Do you want to add %@ to your friends list?",
    "Möchtest du %@ zu deiner Freundesliste hinzufügen?",
    "¿Quieres añadir a %@ a tu lista de amigos?",
    "Voulez-vous ajouter %@ à votre liste d’amis ?",
    "Vuoi aggiungere %@ alla tua lista di amici?",
    "%@ を友だちリストに追加しますか？",
    "Deseja adicionar %@ à sua lista de amigos?",
)

# --- Membership / gift limit ------------------------------------------------
add("Membership", "Mitgliedschaft", "Suscripción", "Abonnement", "Abbonamento", "メンバーシップ", "Assinatura")
add(
    "Unlock unlimited gifts",
    "Unbegrenzte Wünsche freischalten",
    "Desbloquea deseos ilimitados",
    "Débloquer des souhaits illimités",
    "Sblocca desideri illimitati",
    "ウィッシュを無制限に",
    "Desbloqueie desejos ilimitados",
)
add(
    "Unlimited gifts",
    "Unbegrenzte Wünsche",
    "Deseos ilimitados",
    "Souhaits illimités",
    "Desideri illimitati",
    "ウィッシュ無制限",
    "Desejos ilimitados",
)
add(
    "Thanks for supporting North Pole",
    "Danke, dass du North Pole unterstützt",
    "Gracias por apoyar North Pole",
    "Merci de soutenir North Pole",
    "Grazie per il tuo sostegno a North Pole",
    "North Pole を応援いただきありがとうございます",
    "Obrigado por apoiar o North Pole",
)
add(
    "Every list is capped at %lld gifts for now",
    "Jede Liste ist derzeit auf %lld Wünsche begrenzt",
    "Por ahora cada lista admite %lld deseos",
    "Chaque liste est limitée à %lld souhaits pour le moment",
    "Per ora ogni lista è limitata a %lld desideri",
    "現在、各リストは%lld件までです",
    "Por enquanto, cada lista permite %lld desejos",
)
# The two numbers are remaining-then-limit; keep that order in every translation.
add(
    "%lld of %lld free gifts left",
    "Noch %lld von %lld kostenlosen Wünschen",
    "Quedan %lld de %lld deseos gratis",
    "Il reste %lld souhaits gratuits sur %lld",
    "Restano %lld desideri gratuiti su %lld",
    "残り%lld件（無料%lld件中）",
    "Restam %lld de %lld desejos grátis",
)
add(
    "All %lld free gifts used — tap + to add more",
    "Alle %lld kostenlosen Wünsche genutzt – tippe auf +, um mehr hinzuzufügen",
    "Has usado los %lld deseos gratis: toca + para añadir más",
    "Vos %lld souhaits gratuits sont utilisés – touchez + pour en ajouter",
    "Hai usato tutti i %lld desideri gratuiti: tocca + per aggiungerne altri",
    "無料の%lld件をすべて使いました。＋をタップして追加",
    "Você usou os %lld desejos grátis — toque em + para adicionar mais",
)

# --- Plurals ----------------------------------------------------------------
# {lang: {category: value}}. Japanese has a single plural category.
PLURALS = {
    "%lld items": {
        "en": {"one": "%lld item", "other": "%lld items"},
        "de": {"one": "%lld Wunsch", "other": "%lld Wünsche"},
        "es": {"one": "%lld artículo", "other": "%lld artículos"},
        "fr": {"one": "%lld article", "other": "%lld articles"},
        "it": {"one": "%lld articolo", "other": "%lld articoli"},
        "ja": {"other": "%lld件"},
        "pt-BR": {"one": "%lld item", "other": "%lld itens"},
    },
    "Adding %lld friends...": {
        "en": {"one": "Adding %lld friend...", "other": "Adding %lld friends..."},
        "de": {"one": "%lld Freund wird hinzugefügt …", "other": "%lld Freunde werden hinzugefügt …"},
        "es": {"one": "Añadiendo %lld amigo…", "other": "Añadiendo %lld amigos…"},
        "fr": {"one": "Ajout de %lld ami…", "other": "Ajout de %lld amis…"},
        "it": {"one": "Aggiunta di %lld amico…", "other": "Aggiunta di %lld amici…"},
        "ja": {"other": "%lld人の友だちを追加中…"},
        "pt-BR": {"one": "Adicionando %lld amigo…", "other": "Adicionando %lld amigos…"},
    },
}


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def build_catalog(keys, plurals):
    strings = {}
    for key in sorted(keys):
        locs = {}
        for lang, value in T[key].items():
            locs[lang] = unit(value)
        entry = {"localizations": locs}
        if key in MANUAL:
            entry["extractionState"] = "manual"
        strings[key] = entry

    for key, per_lang in plurals.items():
        locs = {}
        for lang, cats in per_lang.items():
            locs[lang] = {
                "variations": {
                    "plural": {cat: unit(val) for cat, val in cats.items()}
                }
            }
        strings[key] = {"localizations": locs}

    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def write(path, catalog):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    print(f"wrote {path} ({len(catalog['strings'])} keys)")


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

write(
    os.path.join(ROOT, "ChristmasWishlist", "Localizable.xcstrings"),
    build_catalog(T.keys(), PLURALS),
)

# --- Share extension (separate bundle, so it needs its own catalog) ----------
EXTENSION_KEYS = [
    "Loading...",
    "Item Name",
    "Link",
    "Cancel",
]
add("Enter item name", "Bezeichnung eingeben", "Introduce el nombre", "Saisir le nom de l’article", "Inserisci il nome", "アイテム名を入力", "Digite o nome do item")
add("Notes", "Notizen", "Notas", "Notes", "Note", "メモ", "Notas")
add("(Optional)", "(Optional)", "(Opcional)", "(Facultatif)", "(Facoltativo)", "（任意）", "(Opcional)")
add("Add any notes...", "Notizen hinzufügen …", "Añade notas…", "Ajoutez des notes…", "Aggiungi note…", "メモを追加…", "Adicione notas…")
add(
    "Add to Wishlist",
    "Zur Wunschliste",
    "Añadir a la lista",
    "Ajouter à la liste",
    "Aggiungi alla lista",
    "リストに追加",
    "Adicionar à lista",
)
add("Debug: Loading shared content...", "Debug: Loading shared content...", "Debug: Loading shared content...", "Debug: Loading shared content...", "Debug: Loading shared content...", "Debug: Loading shared content...", "Debug: Loading shared content...")

EXTENSION_KEYS += [
    "Enter item name",
    "Notes",
    "(Optional)",
    "Add any notes...",
    "Add to Wishlist",
    "❄️",
    "Debug: Loading shared content...",
]

write(
    os.path.join(ROOT, "GiftProduct", "Localizable.xcstrings"),
    build_catalog(EXTENSION_KEYS, {}),
)

# --- InfoPlist --------------------------------------------------------------
INFO = {
    "NSContactsUsageDescription": {
        "en": "We need access to your contacts to help you add friends to your wishlist",
        "de": "Wir benötigen Zugriff auf deine Kontakte, um dir beim Hinzufügen von Freunden zu deiner Wunschliste zu helfen.",
        "es": "Necesitamos acceder a tus contactos para ayudarte a añadir amigos a tu lista de deseos.",
        "fr": "Nous avons besoin d’accéder à vos contacts pour vous aider à ajouter des amis à votre liste de souhaits.",
        "it": "Ci serve l’accesso ai tuoi contatti per aiutarti ad aggiungere amici alla tua lista dei desideri.",
        "ja": "友だちをウィッシュリストに追加できるように、連絡先へのアクセスを許可してください。",
        "pt-BR": "Precisamos acessar seus contatos para ajudar você a adicionar amigos à sua lista de desejos.",
    },
}

info_strings = {}
for key, per_lang in INFO.items():
    info_strings[key] = {
        "extractionState": "manual",
        "localizations": {lang: unit(val) for lang, val in per_lang.items()},
    }

write(
    os.path.join(ROOT, "ChristmasWishlist", "InfoPlist.xcstrings"),
    {"sourceLanguage": "en", "strings": info_strings, "version": "1.0"},
)
