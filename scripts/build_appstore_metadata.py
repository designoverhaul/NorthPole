#!/usr/bin/env python3
"""Write fastlane-style App Store Connect metadata and enforce Apple's limits.

Layout matches `fastlane deliver`: fastlane/metadata/<locale>/<field>.txt
Upload with:  fastlane deliver --skip_binary_upload --skip_screenshots
"""

import os

# Apple's character limits for the fields we manage.
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotional_text": 170,
    "description": 4000,
    "release_notes": 4000,
}

SHARED = {
    "name": "North Pole",
    "support_url": "https://designoverhaul.com/north-pole/",
    "marketing_url": "https://designoverhaul.com/north-pole/",
    "privacy_url": "https://designoverhaul.com/privacy-policy-north-pole/",
}

META = {}

META["en-US"] = {
    "subtitle": "Christmas wishlists, shared",
    "keywords": "christmas,wishlist,gift list,secret santa,holiday,presents,family,gift ideas,registry",
    "promotional_text": "Build your Christmas wishlist, see what your friends and family want, and quietly claim the gift you're buying — no more duplicates.",
    "description": """North Pole is the easiest way to share Christmas wishlists with the people you exchange gifts with — and to quietly coordinate behind the scenes so nobody ends up with two of the same present.

BUILD YOUR LIST IN SECONDS
Found something you want while browsing? Share it straight from Safari or any shopping app and North Pole fills in the name, photo, and price for you. Or add an item by hand with a note about the size, colour, or version you'd like.

SEE WHAT EVERYONE WANTS
Add friends and family from your contacts. As soon as they join, their lists appear alongside yours. Tap a name to see exactly what they're hoping for, with a link straight to the product.

CLAIM A GIFT WITHOUT SPOILING IT
Mark an item as purchased and it turns into a wrapped gift for everyone else — so two people never buy the same thing. The person who wrote the list can choose whether they want to know. Prefer to be surprised? Turn off purchase status and their list looks untouched until Christmas morning.

LISTS FOR KIDS TOO
Children who don't have their own phone can still have a wishlist. Add them under your profile and their lists show up for your friends automatically.

ASK SANTA FOR IDEAS
Stuck on someone? Tell Santa their age, budget, and a few interests, and he'll come back with real, buyable gift ideas — from playful to educational, whichever you prefer.

MADE FOR THE HOLIDAYS
Warm, hand-lettered design, falling snow, and a wrapped gift for every present that's been claimed.

North Pole is free. Sign in with your phone number and you're ready to go.""",
    "release_notes": "North Pole now speaks your language. The whole app is available in Spanish, French, German, Italian, Portuguese, and Japanese — and Santa answers your gift questions in your language too.",
}

META["es-ES"] = {
    "subtitle": "Listas de deseos navideñas",
    "keywords": "navidad,lista de deseos,regalos,amigo invisible,fiestas,familia,ideas de regalo",
    "promotional_text": "Crea tu lista de deseos, mira lo que quieren tus amigos y familiares y marca en secreto el regalo que vas a comprar. Se acabaron los duplicados.",
    "description": """North Pole es la forma más sencilla de compartir listas de deseos navideñas con las personas con las que intercambias regalos, y de coordinaros discretamente para que nadie acabe con dos regalos iguales.

CREA TU LISTA EN SEGUNDOS
¿Has encontrado algo que te gusta mientras navegas? Compártelo desde Safari o desde cualquier app de compras y North Pole rellenará el nombre, la foto y el precio por ti. También puedes añadir un artículo a mano con una nota sobre la talla, el color o la versión que prefieres.

DESCUBRE LO QUE QUIEREN LOS DEMÁS
Añade a tus amigos y familiares desde tus contactos. En cuanto se unan, sus listas aparecerán junto a la tuya. Toca un nombre para ver justo lo que desean, con un enlace directo al producto.

RESERVA UN REGALO SIN DESTRIPARLO
Marca un artículo como comprado y se convertirá en un regalo envuelto para los demás, así nadie compra lo mismo dos veces. Quien escribió la lista decide si quiere enterarse: si prefiere la sorpresa, puede desactivar el estado de compra y su lista se verá intacta hasta la mañana de Navidad.

TAMBIÉN PARA LOS PEQUES
Los niños que aún no tienen teléfono también pueden tener su lista. Añádelos a tu perfil y sus listas aparecerán automáticamente para tus amigos.

PÍDELE IDEAS A PAPÁ NOEL
¿No sabes qué regalar? Dile a Papá Noel la edad, el presupuesto y algunos intereses, y te propondrá regalos reales que puedes comprar, desde los más divertidos hasta los más educativos.

HECHA PARA LAS FIESTAS
Un diseño cálido y escrito a mano, nieve cayendo y un regalo envuelto por cada compra reservada.

North Pole es gratis. Inicia sesión con tu número de teléfono y listo.""",
    "release_notes": "North Pole ya habla tu idioma. Toda la app está disponible en español, francés, alemán, italiano, portugués y japonés, y Papá Noel también responde a tus dudas sobre regalos en tu idioma.",
}

META["fr-FR"] = {
    "subtitle": "Listes de Noël partagées",
    "keywords": "noël,liste de souhaits,cadeaux,secret santa,fêtes,famille,idées cadeaux",
    "promotional_text": "Créez votre liste de Noël, découvrez celle de vos proches et réservez discrètement le cadeau que vous offrez. Fini les doublons.",
    "description": """North Pole est le moyen le plus simple de partager vos listes de Noël avec les personnes à qui vous offrez des cadeaux, et de vous coordonner discrètement pour que personne ne reçoive deux fois la même chose.

CRÉEZ VOTRE LISTE EN QUELQUES SECONDES
Vous avez repéré quelque chose en naviguant ? Partagez-le depuis Safari ou n'importe quelle app de shopping : North Pole récupère le nom, la photo et le prix pour vous. Vous pouvez aussi ajouter un article à la main, avec une note sur la taille, la couleur ou la version souhaitée.

VOYEZ CE QUE VEULENT VOS PROCHES
Ajoutez vos amis et votre famille depuis vos contacts. Dès qu'ils rejoignent l'app, leurs listes apparaissent à côté de la vôtre. Touchez un nom pour voir exactement ce qui leur ferait plaisir, avec un lien direct vers le produit.

RÉSERVEZ UN CADEAU SANS VENDRE LA MÈCHE
Marquez un article comme acheté : il se transforme en cadeau emballé pour les autres, et personne n'achète la même chose. La personne qui a écrit la liste choisit si elle veut le savoir. Envie de garder la surprise ? Il suffit de désactiver l'affichage des achats : la liste reste intacte jusqu'au matin de Noël.

DES LISTES POUR LES ENFANTS AUSSI
Les enfants qui n'ont pas encore de téléphone peuvent avoir leur liste. Ajoutez-les à votre profil et leurs listes apparaîtront automatiquement pour vos amis.

DEMANDEZ DES IDÉES AU PÈRE NOËL
En panne d'inspiration ? Indiquez au Père Noël l'âge, le budget et quelques centres d'intérêt : il vous proposera de vrais cadeaux, du plus ludique au plus éducatif.

PENSÉE POUR LES FÊTES
Un design chaleureux et manuscrit, de la neige qui tombe et un cadeau emballé pour chaque achat réservé.

North Pole est gratuite. Connectez-vous avec votre numéro de téléphone et c'est parti.""",
    "release_notes": "North Pole parle désormais votre langue. Toute l'app est disponible en espagnol, français, allemand, italien, portugais et japonais, et le Père Noël répond lui aussi dans votre langue.",
}

META["de-DE"] = {
    "subtitle": "Wunschlisten für Weihnachten",
    "keywords": "weihnachten,wunschliste,geschenke,wichteln,feiertage,familie,geschenkideen",
    "promotional_text": "Erstelle deine Wunschliste, sieh, was sich deine Liebsten wünschen, und reserviere still und heimlich dein Geschenk. Keine Doppelungen mehr.",
    "description": """North Pole ist der einfachste Weg, Weihnachtswunschlisten mit den Menschen zu teilen, mit denen du Geschenke tauschst – und euch im Hintergrund so abzustimmen, dass niemand dasselbe Geschenk doppelt bekommt.

DEINE LISTE IN SEKUNDEN
Beim Stöbern etwas Schönes entdeckt? Teile es direkt aus Safari oder einer Shopping-App, und North Pole übernimmt Name, Foto und Preis für dich. Oder trage einen Wunsch von Hand ein – mit einer Notiz zu Größe, Farbe oder Variante.

SIEH, WAS SICH ANDERE WÜNSCHEN
Füge Freunde und Familie aus deinen Kontakten hinzu. Sobald sie dabei sind, erscheinen ihre Listen neben deiner. Tippe auf einen Namen und du siehst genau, worüber sie sich freuen würden – mit Link direkt zum Produkt.

GESCHENKE RESERVIEREN, OHNE ZU SPOILERN
Markiere einen Wunsch als gekauft, und für alle anderen wird daraus ein eingepacktes Geschenk. So kauft niemand dasselbe zweimal. Wer die Liste geschrieben hat, entscheidet selbst, ob er es erfahren möchte. Lieber überrascht werden? Einfach die Kaufanzeige ausschalten – dann sieht die Liste bis Heiligabend unberührt aus.

AUCH LISTEN FÜR KINDER
Kinder ohne eigenes Handy können trotzdem eine Wunschliste haben. Lege sie unter deinem Profil an, und ihre Listen erscheinen automatisch bei deinen Freunden.

FRAG DEN WEIHNACHTSMANN
Keine Idee? Nenne dem Weihnachtsmann Alter, Budget und ein paar Interessen – er schlägt echte, kaufbare Geschenke vor, von verspielt bis lehrreich.

GEMACHT FÜR DIE FEIERTAGE
Warmes, handgeschriebenes Design, fallender Schnee und ein eingepacktes Geschenk für jeden reservierten Wunsch.

North Pole ist kostenlos. Melde dich mit deiner Telefonnummer an und leg los.""",
    "release_notes": "North Pole spricht jetzt deine Sprache. Die ganze App gibt es auf Spanisch, Französisch, Deutsch, Italienisch, Portugiesisch und Japanisch – und der Weihnachtsmann antwortet ebenfalls in deiner Sprache.",
}

META["it"] = {
    "subtitle": "Liste dei desideri di Natale",
    "keywords": "natale,lista dei desideri,regali,babbo natale segreto,feste,famiglia,idee regalo",
    "promotional_text": "Crea la tua lista dei desideri, scopri cosa vogliono i tuoi cari e prenota in silenzio il regalo che stai comprando. Niente più doppioni.",
    "description": """North Pole è il modo più semplice per condividere le liste dei desideri di Natale con le persone con cui ti scambi i regali, e per coordinarvi in silenzio così nessuno riceve due volte lo stesso dono.

CREA LA TUA LISTA IN POCHI SECONDI
Hai trovato qualcosa che ti piace mentre navighi? Condividilo da Safari o da qualsiasi app di shopping: North Pole compila nome, foto e prezzo per te. Oppure aggiungi un articolo a mano, con una nota su taglia, colore o versione preferita.

SCOPRI COSA DESIDERANO GLI ALTRI
Aggiungi amici e parenti dai tuoi contatti. Appena si uniscono, le loro liste compaiono accanto alla tua. Tocca un nome per vedere esattamente cosa desiderano, con il link diretto al prodotto.

PRENOTA UN REGALO SENZA ROVINARE LA SORPRESA
Segna un articolo come acquistato e per gli altri diventerà un regalo incartato, così nessuno compra la stessa cosa. Chi ha scritto la lista decide se vuole saperlo: se preferisce la sorpresa, può disattivare lo stato di acquisto e la lista resterà intatta fino alla mattina di Natale.

LISTE ANCHE PER I BAMBINI
I bambini che non hanno ancora un telefono possono comunque avere la loro lista. Aggiungili al tuo profilo e le loro liste appariranno automaticamente ai tuoi amici.

CHIEDI UN'IDEA A BABBO NATALE
Non sai cosa regalare? Indica a Babbo Natale età, budget e qualche interesse: ti proporrà regali veri e acquistabili, dai più giocosi ai più educativi.

PENSATA PER LE FESTE
Un design caldo e scritto a mano, la neve che scende e un regalo incartato per ogni acquisto prenotato.

North Pole è gratuita. Accedi con il tuo numero di telefono e sei pronto.""",
    "release_notes": "North Pole ora parla la tua lingua. Tutta l'app è disponibile in spagnolo, francese, tedesco, italiano, portoghese e giapponese, e anche Babbo Natale risponde nella tua lingua.",
}

META["pt-BR"] = {
    "subtitle": "Listas de desejos de Natal",
    "keywords": "natal,lista de desejos,presentes,amigo secreto,festas,família,ideias de presente",
    "promotional_text": "Monte sua lista de desejos, veja o que sua família e seus amigos querem e reserve em silêncio o presente que você vai comprar. Sem presentes repetidos.",
    "description": """O North Pole é o jeito mais simples de compartilhar listas de desejos de Natal com quem você troca presentes — e de se organizar nos bastidores para que ninguém ganhe o mesmo presente duas vezes.

MONTE SUA LISTA EM SEGUNDOS
Achou algo que você quer enquanto navegava? Compartilhe direto do Safari ou de qualquer app de compras e o North Pole preenche o nome, a foto e o preço para você. Ou adicione um item na mão, com uma observação sobre o tamanho, a cor ou a versão que você prefere.

VEJA O QUE CADA UM QUER
Adicione amigos e familiares dos seus contatos. Assim que eles entrarem, as listas deles aparecem ao lado da sua. Toque em um nome para ver exatamente o que a pessoa quer, com link direto para o produto.

RESERVE UM PRESENTE SEM ENTREGAR A SURPRESA
Marque um item como comprado e ele vira um presente embrulhado para todo mundo, então ninguém compra a mesma coisa. Quem escreveu a lista escolhe se quer saber. Prefere ser surpreendido? É só desativar o status de compra e a lista fica intacta até a manhã de Natal.

LISTAS PARA AS CRIANÇAS TAMBÉM
Crianças que ainda não têm celular também podem ter uma lista. Adicione-as ao seu perfil e as listas delas aparecem automaticamente para seus amigos.

PEÇA IDEIAS AO PAPAI NOEL
Sem ideias? Diga ao Papai Noel a idade, o orçamento e alguns interesses, e ele volta com presentes reais que dá para comprar, dos mais divertidos aos mais educativos.

FEITO PARA AS FESTAS
Design acolhedor e feito à mão, neve caindo e um presente embrulhado para cada compra reservada.

O North Pole é gratuito. Faça login com seu número de telefone e pronto.""",
    "release_notes": "O North Pole agora fala a sua língua. O app inteiro está disponível em espanhol, francês, alemão, italiano, português e japonês — e o Papai Noel também responde no seu idioma.",
}

META["ja"] = {
    "subtitle": "クリスマスのほしい物リスト",
    "keywords": "クリスマス,ほしい物リスト,ウィッシュリスト,プレゼント,ギフト,家族,友だち,贈り物",
    "promotional_text": "自分のほしい物リストを作って、家族や友だちの希望も確認。買う予定のギフトをそっと予約できるので、プレゼントがかぶりません。",
    "description": """North Pole は、プレゼントを贈り合う相手とクリスマスのほしい物リストを共有し、裏側でそっと調整して同じ贈り物が重ならないようにするアプリです。

数秒でリストを作成
ネットを見ていて気になるものを見つけたら、Safari やショッピングアプリからそのまま共有するだけ。North Pole が商品名・写真・価格を自動で読み取ります。サイズや色、希望のバージョンをメモに書いて、手入力で追加することもできます。

みんなの希望がひと目でわかる
連絡先から家族や友だちを追加できます。相手がアプリを使い始めると、そのリストがあなたのリストの隣に並びます。名前をタップすれば、欲しいものと商品ページへのリンクをそのまま確認できます。

サプライズを壊さずにギフトを予約
アイテムを購入済みにすると、ほかの人にはラッピングされたギフトとして表示されます。だから同じものを二人で買ってしまう心配はありません。知りたいかどうかはリストの持ち主が選べます。サプライズを楽しみたいなら購入状況の表示をオフに。クリスマスの朝まで、リストは手つかずのままに見えます。

子ども用のリストも
自分のスマホを持っていないお子さんも、ほしい物リストを作れます。プロフィールに追加すれば、友だちの画面にも自動で表示されます。

サンタにアイデアを聞く
何を贈るか迷ったら、年齢・予算・興味をサンタに伝えてみてください。実際に買える具体的なギフトを、遊び心のあるものから学びになるものまで提案してくれます。

ホリデーのための デザイン
手書き風のあたたかいデザイン、降り積もる雪、そして予約されたプレゼントごとに現れるラッピングされたギフト。

North Pole は無料です。電話番号でサインインすれば、すぐに使い始められます。""",
    "release_notes": "North Pole が日本語に対応しました。アプリ全体をスペイン語・フランス語・ドイツ語・イタリア語・ポルトガル語・日本語でご利用いただけます。サンタもあなたの言語で答えてくれます。",
}


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "fastlane", "metadata")

problems = []
for locale, fields in META.items():
    d = os.path.join(BASE, locale)
    os.makedirs(d, exist_ok=True)
    merged = dict(SHARED)
    merged.update(fields)
    for field, value in merged.items():
        limit = LIMITS.get(field)
        if limit and len(value) > limit:
            problems.append(f"{locale}/{field}: {len(value)} chars (limit {limit})")
        with open(os.path.join(d, field + ".txt"), "w", encoding="utf-8") as f:
            f.write(value.strip() + "\n")
    print(f"{locale}: subtitle {len(merged['subtitle'])}/30, "
          f"keywords {len(merged['keywords'])}/100, "
          f"promo {len(merged['promotional_text'])}/170, "
          f"description {len(merged['description'])}/4000")

if problems:
    print("\nOVER LIMIT:")
    for p in problems:
        print("  " + p)
    raise SystemExit(1)
print("\nAll fields within Apple's limits.")
