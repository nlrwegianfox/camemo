Name:       CAmemo

Summary:    CA memo  (Carassius auratus memo)
Version:    0.9.5
Release:    1
License:    MIT

Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils

%description
CA Memo: For the Goldfish Brain
Let’s be honest: Carassius auratus (the humble goldfish) has roughly the same memory span as the creator of this app.
Ideas flash by like lightning—brilliant sparks that vanish before you can blink. That TV show your grandma whispered about? The one that totally flipped your perception of her forever? Gone. Poof.
But here’s the thing: with CA Memo, you can scribble it down in a heartbeat.
"Series #Grandma Dexter" → Done.
And the best part? If you can recall even a tiny fragment of that note—just a word, a feeling, a half-baked thought—it’ll pop back up faster than you can forget it again.
Sure, you could organize your notes into fancy folders and meticulously labeled notebooks. But let’s be real: if you’re anything like us, that structure will crumble faster than a dry biscuit. You won’t remember where you filed it anyway. So why bother?
CA Memo gives you the freedom to organize… if you really want to. But if you’re like us? Just toss everything into one big, chaotic notepad. Throw in a few keywords, and let the search engine do the heavy lifting.
Because at the end of the day, all you need to remember is:
"Grandma suggested a show that sounded kinda f*****."
The rest? We’ve got it covered.
Search: #Grandma
One swipe down from anywhere to create a note
NB:
This app is built upon original ideas, functional requirements, and design concepts created by the developer. AI tools were extensively used to assist with the coding process and translation.


%prep
%setup -q -n %{name}-%{version}

%build

%qmake5

%make_build


%install
%qmake5_install


desktop-file-install --delete-original         --dir %{buildroot}%{_datadir}/applications                %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%doc LICENSE.txt
