//
//  SettingView.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 03/11/2024.
//

import SwiftUI

struct CountrySelectorView: View {
    @State private var searchText: String = ""
    @EnvironmentObject var appManager: AppManager
    @State private var selectedCountry: Country? = nil
    @State private var countries: [Country] = [
        Country(name: "United States", flag: "🇺🇸", language: "English", languageCode: "en"),
        Country(name: "Canada", flag: "🇨🇦", language: "French", languageCode: "fr"),
        Country(name: "United Kingdom", flag: "🇬🇧", language: "English", languageCode: "en"),
        Country(name: "India", flag: "🇮🇳", language: "Hindi", languageCode: "hi"),
        Country(name: "Germany", flag: "🇩🇪", language: "German", languageCode: "de"),
        Country(name: "Australia", flag: "🇦🇺", language: "English", languageCode: "en"),
        Country(name: "Japan", flag: "🇯🇵", language: "Japanese", languageCode: "ja"),
        Country(name: "France", flag: "🇫🇷", language: "French", languageCode: "fr"),
        Country(name: "Brazil", flag: "🇧🇷", language: "Portuguese", languageCode: "pt"),
        Country(name: "Russia", flag: "🇷🇺", language: "Russian", languageCode: "ru"),
        Country(name: "China", flag: "🇨🇳", language: "Mandarin", languageCode: "zh"),
        Country(name: "South Korea", flag: "🇰🇷", language: "Korean", languageCode: "ko"),
        Country(name: "Italy", flag: "🇮🇹", language: "Italian", languageCode: "it"),
        Country(name: "Spain", flag: "🇪🇸", language: "Spanish", languageCode: "es"),
        Country(name: "Mexico", flag: "🇲🇽", language: "Spanish", languageCode: "es"),
        Country(name: "Saudi Arabia", flag: "🇸🇦", language: "Arabic", languageCode: "ar"),
        Country(name: "Sweden", flag: "🇸🇪", language: "Swedish", languageCode: "sv"),
        Country(name: "Norway", flag: "🇳🇴", language: "Norwegian", languageCode: "no"),
        Country(name: "Netherlands", flag: "🇳🇱", language: "Dutch", languageCode: "nl"),
        Country(name: "Turkey", flag: "🇹🇷", language: "Turkish", languageCode: "tr"),
        Country(name: "South Africa", flag: "🇿🇦", language: "Afrikaans", languageCode: "af"),
        Country(name: "Egypt", flag: "🇪🇬", language: "Arabic", languageCode: "ar"),
        Country(name: "Thailand", flag: "🇹🇭", language: "Thai", languageCode: "th"),
        Country(name: "Vietnam", flag: "🇻🇳", language: "Vietnamese", languageCode: "vi"),
        Country(name: "Argentina", flag: "🇦🇷", language: "Spanish", languageCode: "es"),
        Country(name: "Nigeria", flag: "🇳🇬", language: "English", languageCode: "en"),
        Country(name: "Indonesia", flag: "🇮🇩", language: "Indonesian", languageCode: "id"),
        Country(name: "Pakistan", flag: "🇵🇰", language: "Urdu", languageCode: "ur"),
        Country(name: "Bangladesh", flag: "🇧🇩", language: "Bengali", languageCode: "bn"),
        Country(name: "Philippines", flag: "🇵🇭", language: "Filipino", languageCode: "fil"),
        Country(name: "Malaysia", flag: "🇲🇾", language: "Malay", languageCode: "ms"),
        Country(name: "Iran", flag: "🇮🇷", language: "Persian", languageCode: "fa"),
        Country(name: "Iraq", flag: "🇮🇶", language: "Kurdish", languageCode: "ar, ku"),
        Country(name: "Israel", flag: "🇮🇱", language: "Hebrew", languageCode: "he"),
        Country(name: "Portugal", flag: "🇵🇹", language: "Portuguese", languageCode: "pt"),
        Country(name: "Poland", flag: "🇵🇱", language: "Polish", languageCode: "pl"),
        Country(name: "Czech Republic", flag: "🇨🇿", language: "Czech", languageCode: "cs"),
        Country(name: "Hungary", flag: "🇭🇺", language: "Hungarian", languageCode: "hu"),
        Country(name: "Romania", flag: "🇷🇴", language: "Romanian", languageCode: "ro"),
        Country(name: "Ukraine", flag: "🇺🇦", language: "Ukrainian", languageCode: "uk"),
        Country(name: "Greece", flag: "🇬🇷", language: "Greek", languageCode: "el"),
        Country(name: "Serbia", flag: "🇷🇸", language: "Serbian", languageCode: "sr"),
        Country(name: "Switzerland", flag: "🇨🇭", language: "French", languageCode: "de"),
        Country(name: "Denmark", flag: "🇩🇰", language: "Danish", languageCode: "da"),
        Country(name: "Finland", flag: "🇫🇮", language: "Finnish", languageCode: "fi, sv"),
        Country(name: "Iceland", flag: "🇮🇸", language: "Icelandic", languageCode: "is"),
        Country(name: "Estonia", flag: "🇪🇪", language: "Estonian", languageCode: "et"),
        Country(name: "Latvia", flag: "🇱🇻", language: "Latvian", languageCode: "lv"),
        Country(name: "Lithuania", flag: "🇱🇹", language: "Lithuanian", languageCode: "lt"),
        Country(name: "Belarus", flag: "🇧🇾", language: "Russian", languageCode: "be"),
        Country(name: "Kazakhstan", flag: "🇰🇿", language: "Russian", languageCode: "kk"),
    ]
    
    
    
    var filteredCountries: [Country] {
        var list = searchText.isEmpty
        ? countries
        : countries.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        
        if let selected = countries.first(where: { $0.languageCode == appManager.appLanguage }) {
            if let index = list.firstIndex(where: { $0.id == selected.id }) {
                list.remove(at: index)
            }
            list.insert(selected, at: 0)
        }
        
        return list
    }
    
    var body: some View {
        VStack {
            
            TextField("Search countries", text: $searchText)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            
            List(filteredCountries) { country in
                HStack {
                    Text(country.flag)
                        .font(.largeTitle)
                    VStack(alignment: .leading) {
                        Text(country.language)
                            .font(.headline)
                        Text("\(country.languageCode)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    if selectedCountry?.id == country.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCountry = country
                    appManager.appLanguage = country.languageCode
                    appManager.languageName = country.language
                }
            }
            .listStyle(PlainListStyle())
            .padding()
        }
        .navigationTitle("Select Language")
        .onAppear {
            if let selected = countries.first(where: { $0.languageCode == appManager.appLanguage }) {
                selectedCountry = selected
            }
        }
        
    }
}


struct CountrySelectorView_Previews: PreviewProvider {
    static var previews: some View {
        CountrySelectorView()
    }
}
